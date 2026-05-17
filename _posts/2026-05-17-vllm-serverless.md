---
layout: category-post
title:  "Can serverless GPU be an alternative for Local LLMs ?"
date:   2026-05-17
categories: blog
---

> TLDR:
> I explore serverless GPU inference as an alternative for local and private
> LLMs. In the process, I optimize the cold start time of serverless inference
> by 6.5x — from **460s down to ~70s** — by combining vLLM sleep mode with
> Modal's GPU memory snapshots. The full setup is in this repo - [vllm_serverless](https://github.com/infinitylogesh/vllm-serverless).


I should start by saying I am very bullish on local models. I believe that in the nearish future, a non-trivial amount of LLM generation will happen locally.

But that is in the future. In my present day, I am RAM Poor, I only have a 16 GB memory Mac. Which is barely enough for my work tasks. Let alone share that with a local LLM.

I do need a private model for some of my personal automations and a few cli tasks. These workflows touch sensitive personal data: email, transactions and other documents. For these use cases, sending everything to a shared hosted API is not always ideal.

Also, for my usage pattern, a dedicated GPU instance does not make sense either. The workload is intermittent, personal, and bursty. I do not want to keep a GPU running 24/7 just so a few automations can call it occasionally.

So I started exploring a middle ground:

> Can serverless GPU hosting become a practical alternative to local models, especially for models that do not fit on my local machine?

Even though it is not as airtight as running a model fully locally, it gives me something useful: my own private instance, scale-to-zero economics, and enough control over the serving stack.

The goal was simple:

> Run a private `vLLM` instance serving `Qwen/Qwen3.6-27B-FP8`, scale it down to zero, and get cold start time low enough that it is usable for personal workload.

For these experiments, I used [Modal](https://modal.com) as the serverless platform and an `A100-80GB` GPU. The complete setup is in repo - [vllm_serverless](https://github.com/logeshv/local_serverless).

---

## **Baseline: the simplest vLLM server**

I started with a bare-minimum vLLM configuration:

```bash
vllm serve Qwen/Qwen3.6-27B-FP8 \
  --uvicorn-log-level info \
  --served-model-name qwen3.6-27b \
  --host 0.0.0.0 \
  --port 8000 \
  --trust-remote-code \
  --api-key <api_key> \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --safetensors-load-strategy=prefetch \
  --no-enforce-eager
```

The result was not encouraging but expected. Cold start time: **460 seconds** (**7 minutes 40 seconds**).

That is too slow for anything useful. If a background job or personal assistant has to wait almost eight minutes before it can answer, the UX is effectively broken.

So I profiled the startup logs to understand where the time was spent.

| **Rank** | **Area** | **Time** | **% of total startup** |
| --- | --- | --- | --- |
| 1 | Engine init: profile + KV cache + warmup + compile | **326.24 s** | **70.7%** |
| 2 | `torch.compile` | **164.38 s** | **35.6%** |
| 3 | Initial profiling / warmup run | **93.68 s** | **20.3%** |
| 4 | CUDA graph capture | **44 s** | **9.5%** |
| 5 | Pre-EngineCore tokenizer / MM processor setup | **~30.7 s** | **6.7%** |
| 6 | Post-engine multimodal warmups | **18.79 s** | **4.1%** |
| 7 | Model loading | **12.43 s** | **2.7%** |

The surprising part was that model loading itself was not the main problem. The weights were already cached on Modal's attached volume, so the raw model loading time was relatively small.

The real cost was vLLM engine initialization: profiling, KV cache setup, warmup, compilation, and CUDA graph capture. These are mostly one-time costs paid every cold start — exactly the kind of work that benefits from snapshotting.

---

## **Dialling down the expensive optimisations**

Now that I knew the main culprits, I wanted to try an extreme configuration.

This was not the configuration I wanted to use permanently. It disables several optimisations that are valuable for throughput and steady-state performance. But I wanted to understand the lower bound: how much cold start time could I remove just by turning down the startup-heavy features?

The changes were:

1. Skip compile and CUDA graph capture with `--enforce-eager`.
2. Reduce maximum model context length and batch size to reduce KV cache profiling and warmup cost:
    - `--max-num-seqs 16`
    - `--max-num-batched-tokens 2048`
    - `--max-model-len 32768`
3. Disable multimodal support to avoid multimodal warmup:
    - `--language-model-only`
    - `--limit-mm-per-prompt '{"image":0,"video":0}'`
4. Keep model loading optimized through Modal's attached volume cache.

The new command looked like this:

```bash
vllm serve Qwen/Qwen3.6-27B-FP8 \
  --uvicorn-log-level info \
  --served-model-name qwen3.6-27b \
  --host 0.0.0.0 \
  --port 8000 \
  --trust-remote-code \
  --api-key <api-key> \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --max-num-batched-tokens 2048 \
  --max-num-seqs 16 \
  --safetensors-load-strategy=prefetch \
  --max-model-len 32768 \
  --limit-mm-per-prompt '{"image":0,"video":0}' \
  --language-model-only \
  --enforce-eager \
  --tensor-parallel-size 1
```

This helped a lot. Cold start dropped from **460 seconds** to **219 seconds** (**3 minutes 39 seconds**). That is almost a 2x improvement.

The main costs removed were:

| **Removed cost** | **Previous time** |
| --- | --- |
| `torch.compile` | **164.38 s** |
| CUDA graph capture | **44 s** |
| CUDA graph memory profiling overhead | **~20 s** |
| Read-only multimodal warmup | **9.16 s** |

This was a useful result, but still nowhere near the target.

Three and a half minutes is better than eight minutes, but it is still too slow for an on-demand personal model. Also, this was achieved with an intentionally compromised serving configuration — no `torch.compile`, no CUDA graphs, no multimodal. Steady-state throughput suffers.

At this point, the main remaining startup cost was still vLLM engine initialization: profiling, KV cache creation, warmup, and getting the model into a ready-to-serve state.

So I started looking for other options.

That led me to Modal's GPU memory snapshotting.

---

## **Enter vLLM sleep mode and Modal GPU snapshots**

I came to know that vLLM has a feature called **sleep mode**, which acts like a hibernation mechanism for the vLLM engine. It was originally designed for scenarios like model switching, where you want to free GPU memory and later wake the model without paying the full reload cost again. The [vLLM blog](https://vllm.ai/blog/2025-10-26-sleep-mode) describes sleep mode as a way to preserve expensive runtime state and avoid repeated reload overheads.

vLLM supports two sleep levels:

| **Sleep level** | **What happens** | Results |
| --- | --- | --- |
| Level 1 | Offloads model weights to CPU RAM and discards KV cache | Faster wake up time, high CPU RAM usage |
| Level 2 | Discards both model weights | Slower wake up time, low CPU RAM usage |

The official vLLM docs describe Level 1 as backing up model weights in CPU memory; Level 2 discards model weights.

For my use case, I want to wake the same private model repeatedly. Thus Level 1 suits my needs.

To enable the `/sleep` and `/wake_up` HTTP endpoints, two things need to line up:

1. Pass `--enable-sleep-mode` to `vllm serve`.
2. Set `VLLM_SERVER_DEV_MODE=1` in the container environment — without it, the endpoints are not registered. This is set in [config.yaml](config.yaml) under `service.env`.

Modal's GPU memory snapshots are the other half of the puzzle. Modal's documentation describes two snapshot types: CPU memory snapshots, which capture the container's CPU memory state, and GPU memory snapshots, an alpha feature that also captures GPU state. [Modal's blog](https://modal.com/blog/gpu-mem-snapshots) positions GPU snapshots as a way to avoid repeating expensive GPU initialization work during cold starts.

The idea was:

1. Start the vLLM server normally once.
2. Let it complete model loading, profiling, warmup, and initialization.
3. Run a few warmup requests to force `torch.compile` and CUDA graph capture to happen *before* the snapshot is taken.
4. Put vLLM into sleep mode so the GPU state is small and clean.
5. Let Modal snapshot the CPU and GPU state.
6. On future cold starts, restore from the snapshot instead of repeating the full initialization path.

This is a very different model from "start container, load model, initialize engine" on every cold boot.

Instead, the restored container is already much closer to the serving-ready state.

---

## **How it is wired up in the repo**

Modal's lifecycle hooks make this surprisingly clean. The relevant primitive is `@modal.enter(snap=True)` vs `@modal.enter(snap=False)` — the former runs **once**, before the snapshot is taken; the latter runs on **every cold start**, including snapshot restores.

The pre-snapshot hook does the heavy lifting (Full code in [service.py](https://github.com/infinitylogesh/vllm-serverless/blob/main/service.py)):

```python
@modal.enter(snap=True)
def start(self):
    # Runs BEFORE the snapshot is taken — only on a fresh cold start.
    # Steps: start vllm → wait ready → warmup (captures CUDA graphs) → sleep
    # After sleep() returns, Modal takes the GPU snapshot.
    # The snapshot contains: model weights (CPU), compiled kernels, CUDA graphs.
    ...
    self.proc = subprocess.Popen(cmd)
    _wait_ready(self.proc)
    _warmup()   # 3 chat completions → forces JIT + CUDA graph capture
    _sleep()    # POST /sleep?level=1 → moves weights GPU → CPU
```

The warmup loop is just three chat completions — that is enough to force `torch.compile` and CUDA graph capture along every path the production traffic will hit. Those compiled kernels are now in the snapshot, free on every future restore.

The post-snapshot hook is a one-liner:

```python
@modal.enter(snap=False)
def wake_up(self):
    # Runs on EVERY cold start including after snapshot restore.
    # Reloads model weights from CPU back to GPU.
    _wake_up()
    _wait_ready(self.proc)
```

A few of the less-obvious knobs that mattered:

- **`TORCHINDUCTOR_COMPILE_THREADS=1`** — required for snapshot compatibility. Multi-threaded inductor compilation creates state that does not survive a snapshot/restore.
- **`--max-cudagraph-capture-size 32`** — limits the batch sizes for which CUDA graphs are captured. Smaller capture set → smaller snapshot, lower peak memory during the one-time capture phase, faster warmup.
- **`gpu_memory_utilization: 0.85`** — leaves headroom for the snapshot/restore machinery itself. The default 0.9 was occasionally tight.
- **`enable_memory_snapshot=True` + `experimental_options={"enable_gpu_snapshot": True}`** — both flags are required on the `@app.cls` decorator. The first enables CPU snapshots, the second turns on the alpha GPU path.
- **Speculative decoding** with `mtp` and `num_speculative_tokens=2` is kept on — it lives inside the snapshot, so it adds no cold-start cost.

One small surprise: the snapshot is not materialized on the very first cold start. Modal needs a few warm boots before it captures and finalizes the snapshot. In practice I saw it stabilize after **3–5 invocations**.

---

## **The result: 70-second cold starts**

After enabling the snapshot flow, I had to allow a few invocations (up to 5 cold start invocations) for Modal's memory snapshot to materialize. Once the snapshot was available, subsequent cold starts used the snapshot path.

The cold start time dropped to around **70 seconds**.

Here is the full progression:

| **Configuration** | **Cold start time** |
| --- | --- |
| Baseline vLLM config | **460 s** |
| Minimal eager config | **219 s** |
| vLLM sleep mode + Modal GPU memory snapshot | **~70 s** |

That is roughly a **6.5x improvement** from the original baseline.

And critically, the 70s number is achieved with the **full** serving config — `torch.compile` on, CUDA graphs on, multimodal on, speculative decoding on. None of the steady-state throughput is sacrificed; the expensive setup just happens once and lives inside the snapshot.

Is 70 seconds perfect? No.

Is it the same as a truly local model sitting in memory on my laptop? Also no.

But for my personal use case, it crosses an important threshold. A one-minute cold start is something I can design around — most of my automations are async or batched anyway.

The key point is that I can now run a larger private model without paying for an always-on dedicated GPU.

---

## **Why is this interesting**

This experiment changed how I think about "local models."

There is a spectrum:

| **Option** | **Privacy** | **Cost** | **Latency** | **Model size** |
| --- | --- | --- | --- | --- |
| Fully local model | Best | Fixed hardware cost | Best when warm | Limited by local hardware |
| Hosted API | Weakest control | Pay per token | Usually excellent | Very large models available |
| Dedicated GPU server | Good control | Expensive if idle | Good when warm | Large models |
| Serverless private GPU | Good practical control | Pay mostly on use | Cold start tradeoff | Larger than local |

Serverless GPUs are not a replacement for true local inference. But for models that do not fit locally, they are a useful middle ground — and a 70-second cold start is a much smaller tax than I expected to be paying when I started this experiment.

The full deployable setup is in this repo - [vllm_serverless](https://github.com/infinitylogesh/vllm-serverless).

<div class="hero-links">
  <a href="https://github.com/infinitylogesh/vllm-serverless" class="hero-links__external">GitHub</a>
</div>
