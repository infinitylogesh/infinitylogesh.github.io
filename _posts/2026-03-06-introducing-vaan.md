---
layout: category-post
title:  "Introducing Vaan: Bringing the power of multimodal LLMs to the real world live video streams"
date:   2026-03-06
categories: blog
---
<video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/elderly_falling_edited_v1.mp4" autoplay loop muted playsinline controls preload="metadata" width="800rem"></video>
<figcaption style="text-align: center;">Vaan alerts when a person / elderly falls down. Query: "Alert me if you see people falling down"</figcaption>

<div class="hero-links">
  <a href="#demo">Demo</a>
  <a href="https://github.com/ambient-intelligence-hq/vaan" class="hero-links__external">GitHub</a>
  <a href="https://discord.gg/fdeCaGy5T4" class="hero-links__external">Discord</a>
  <a href="https://github.com/ambient-intelligence-hq/vaan?tab=readme-ov-file#getting-started" class="hero-links__external">Getting Started</a>
</div>

<br>

<br>

Cameras are everywhere — in our homes, on our streets, in stores, at intersections, in care centers, in mobile devices and across the systems we rely on every day. Yet most of them are still just passive recordings: endless hours of footage that no one watches unless something has already gone wrong.

What if live video systems could do more than just record? What if they could understand context, reason over events, and alert only when something genuinely important happens? — even across thousands of hours of uneventful footage? Better yet, what if they could anticipate important events before they fully unfold?

A system like that could make streets safer, help elders live more independently, give parents greater peace of mind, and make homes more secure.

Vaan is a step in that direction. Its goal is to be a flexible, promptable system for monitoring live video streams and alerting users when important events of interests happen.

# How it works

## Problem

The core problem in live video understanding is sparsity. In most real-world streams, the events we care about are rare. 

A fall, an accident, a theft, an abandoned item, or an unusual event may happen only once in thousands of hours of footage. In many streams, it may never happen at all. And yet the system has to stay ready, keep watching, and make the right call in real time. This makes the problem fundamentally different from the typical short-context perception tasks that multimodal LLMs have shown strong capabilities for.

Because of this, we cannot process the entire stream with multimodal LLMs in the traditional way (limitations: context windows , latency and the cost ). At the same time, we still want to leverage the world understanding and reasoning capabilities of multimodal LLMs and to have the flexibility of handling variety of events <b>just with text based queries</b> and not complex configuration or event specific pipelines.

## Approach

#### Inspiration

If we squint a little, this problem looks very similar to the one faced by live voice assistants. Live voice assistants deal with a comparable challenge, though usually in a less extreme form. Where the signal of interest — user speech — is also sparse relative to the total duration of the stream.They must continuously determine when the user is speaking and when she is not.

This is why modern voice assistants built on top of general-purpose LLMs do not hand off transcript / raw audio continuously to the model. Instead, they use a staged pipeline that cheaply filters, segments, and validates candidate moments before escalating to a more capable and more expensive model.

Modern live voice assistant systems such as [LiveKit Agents](https://github.com/livekit/agents) address this using a pipeline like the one shown below:

<img src="{{ site.baseurl }}/assets/images/voice-assistant-flow-2.png" alt="Voice assistant architecture" width="900" class="zoomable-image">

The key stages in that pipeline are:

* The audio stream is chunked and passed through a VAD (voice activity detection) model to determine whether the user is speaking, whether speech is ongoing, and whether the user has paused or finished speaking.
* Once a pause or end of speech is detected, the chunk is sent to a transcription model to generate text.
* A pause detected by VAD does not necessarily mean the user has completed their thought. For example: *“I want to switch on the lights … (pause) in the dining room.”* To avoid handing incomplete input to the LLM, an end-of-turn detection model is used to determine whether the transcript actually represents a complete user turn.
* Once the transcript is classified as complete and end-of-turn, it is passed to the LLM to generate a response.
* The response is then sent to a TTS (text-to-speech) model to produce audio output.

All of these steps are executed in a streaming manner to reduce both latency and context usage. 

At a high level, the solution is to first use a cheap and fast mechanism to speculate whether an event of interest has occurred — in the voice assistant case, speech and turn detection — and then hand over only the relevant context to a more accurate but more expensive LLM for verification and response generation.

This is similar to what Vaan attempts to achieve for live video streams.

#### Solution

Vaan uses a relatively cheap and fast mechanism to speculate whether an event of interest may have occurred — using rerankers or embedding-based retrievers — and then accumulates the relevant context before passing it to a more accurate but more expensive LLM to verify the event and generate the required response.

Here is a high-level overview of the architecture:

<img src="{{ site.baseurl }}/assets/images/system_architecture_3.png" alt="Voice assistant architecture" style="width: 100%;" class="zoomable-image">

The key stages in this pipeline are:

* Once a stream is submitted, it is picked up by a stream worker for processing.
* The stream worker continuously chunks the video stream and passes each chunk to a screener (reranker) model to determine whether it is relevant to the trigger queries.
* If a chunk is identified as relevant, it is passed — along with neighboring chunks and other relevant context — to an LLM worker.
* The LLM worker reasons over the context, verifies the event and generates , extracting the required information for the alert.

<div id="demo"></div>
# Demo

We’ve put together a few demos of Vaan in action across very different real-world scenarios on a demo UI ( scroll horizontally over the videos to see them all ):

- Alerting when a baby has fallen down or may have gotten hurt.
- Alerting when uninvited wildlife shows up to raid the cat food.
- Alerting when Santa places a gift. (yes — Santa can’t sneak past this one 😅)
- Alerting when a vehicle accident occurs at an intersection.
- Alerting when a customer completes a checkout and walks away leaving their items behind.
- Alerting when a person / elderly falls down.

<br>

<div class="demo-carousel" data-carousel style="--demo-slide-width: 45rem; --demo-video-aspect: 16 / 9;">
  <div class="demo-carousel__viewport" data-carousel-track>
    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/baby_falling_demo_edited.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when a baby has fallen down or may have gotten hurt.<br> Query: "baby getting hurt or falling down"</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/fox_cat_demo_v3.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when uninvited wildlife shows up to raid the cat food.<br> Query: "when the wildlife eats the cat foold. tell me only when it starts eating"</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/santa_places_gift_edited_v1.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when Santa places a gift.<br> Query: "Alert me when santa places the gift in the christmas tree"</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/seattle_car_accident_demo.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when a vehicle accident occurs at an intersection.<br> Query: "alert me when an accident involving vehicles happen"</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/shopping_missing_detection_edited.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when a customer completes a checkout and walks away leaving their items behind.<br> Query: "a customer completes a checkout and walks away leaving their items behind"</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/elderly_falling_edited_v1.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Vaan alerts when a person falls down.<br> Query: "Alert me if you see people falling down"</figcaption>
    </figure>
  </div>

  <div class="demo-carousel__controls">
    <button type="button" class="demo-carousel__button demo-carousel__button--muted" data-carousel-prev data-carousel-direction="prev" aria-label="Show previous demo"></button>
    <button type="button" class="demo-carousel__button demo-carousel__button--primary" data-carousel-next data-carousel-direction="next" aria-label="Show next demo"></button>
  </div>
</div>

<div class="image-lightbox" data-image-lightbox hidden>
  <button type="button" class="image-lightbox__close" data-image-lightbox-close aria-label="Close image zoom"></button>
  <img src="" alt="" class="image-lightbox__image" data-image-lightbox-image>
</div>

<script>
  (function () {
    var carousels = document.querySelectorAll('[data-carousel]');

    carousels.forEach(function (carousel) {
      var track = carousel.querySelector('[data-carousel-track]');
      var prev = carousel.querySelector('[data-carousel-prev]');
      var next = carousel.querySelector('[data-carousel-next]');
      if (!track || !prev || !next) return;

      var scrollBySlide = function (direction) {
        var slide = track.querySelector('.demo-carousel__slide');
        var gap = parseFloat(window.getComputedStyle(track).columnGap || window.getComputedStyle(track).gap || 0);
        var amount = slide ? slide.getBoundingClientRect().width + gap : track.clientWidth;
        track.scrollBy({ left: direction * amount, behavior: 'smooth' });
      };

      prev.addEventListener('click', function () { scrollBySlide(-1); });
      next.addEventListener('click', function () { scrollBySlide(1); });
    });

    var lightbox = document.querySelector('[data-image-lightbox]');
    var lightboxImage = document.querySelector('[data-image-lightbox-image]');
    var lightboxClose = document.querySelector('[data-image-lightbox-close]');
    var zoomableImages = document.querySelectorAll('.zoomable-image');

    if (lightbox && lightboxImage && lightboxClose && zoomableImages.length) {
      var closeLightbox = function () {
        lightbox.hidden = true;
        document.body.classList.remove('image-lightbox-open');
        lightboxImage.src = '';
        lightboxImage.alt = '';
      };

      zoomableImages.forEach(function (image) {
        image.addEventListener('click', function () {
          lightboxImage.src = image.currentSrc || image.src;
          lightboxImage.alt = image.alt || '';
          lightbox.hidden = false;
          document.body.classList.add('image-lightbox-open');
        });
      });

      lightboxClose.addEventListener('click', closeLightbox);
      lightbox.addEventListener('click', function (event) {
        if (event.target === lightbox) closeLightbox();
      });
      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && !lightbox.hidden) closeLightbox();
      });
    }
  })();
</script>

<br>

<br>

<div id="getting-started"></div>
# Getting started

Follow the instructions in the [README](https://github.com/ambient-intelligence-hq/vaan?tab=readme-ov-file#getting-started) to setup and get started.


<div id="current-limitations"></div>
# Current limitations

- The screener model uses `Qwen3-VL-Reranker-2B` to perform fast verification of chunks against the trigger queries. Out of the box, the model shows poor separability of classes: negative examples typically score below 53%, while positive examples are often only slightly higher, in the 55–57% range. This leaves little margin for reliable thresholding. 

- We found that a threshold of 0.55 provides a good balance between precision and recall. However, the optimal threshold depends on the use case, so it may need to be adjusted based on your requirements. We recommend starting with 0.55 and calibrating it on your own data.

- Current frontier multimodal LLMs are reasonably good at understanding videos and detecting actions, but they still do not perform as well on video reasoning tasks as they do on text reasoning tasks. To illustrate this, here are two examples of false positives.

  1. In the first example, the model misinterprets overhead power lines on the street as fallen lines. It then combines this perception error with the presence of a police or emergency vehicle in the corner of the frame — likely from the aftermath of a different incident — and incorrectly classifies the scene as a car accident. The camera angle makes the power lines appear as though they are lying on the road, but for a human observer it is fairly obvious that this is not an accident scene.

  2. In the second example, the trigger query is: "a customer completes a checkout and walks away leaving their items behind." Here, the model fails to distinguish between empty shopping bags placed at the end of the checkout aisle and the customer’s actual items. As a result, it incorrectly concludes that the customer has walked away and left their items behind. 

This behavior is not specific to any one model. We observe similar failure modes across current frontier multimodal LLMs with native video support, including `gemini-3.1-pro-preview`, `gemini-3-flash-preview`, `qwen3.5-plus-02-15`, and `glm-4.6v`.


<br>

<br>

<div class="demo-carousel" data-carousel style="--demo-slide-width: 50rem; --demo-video-aspect: 16 / 9;">
  <div class="demo-carousel__viewport" data-carousel-track>
    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/false_positive_car_accident_edited.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Limitation Example 1: The model mistakes overhead street power lines for fallen lines and incorrectly flags the scene as a car accident.</figcaption>
    </figure>

    <figure class="demo-carousel__slide">
      <video src="https://pub-3d45716910b34ddaac4aced54197b940.r2.dev/videos/shopping_error_edited.mp4" autoplay loop muted playsinline controls preload="metadata"></video>
      <figcaption>Limitation Example 2: Query: "a customer completes a checkout and walks away leaving their items behind".<br> The model mistakes empty bags near the checkout aisle for abandoned items and incorrectly flags the customer as leaving without them.
</figcaption>
    </figure>
  </div>

  <div class="demo-carousel__controls">
    <button type="button" class="demo-carousel__button demo-carousel__button--muted" data-carousel-prev data-carousel-direction="prev" aria-label="Show previous demo"></button>
    <button type="button" class="demo-carousel__button demo-carousel__button--primary" data-carousel-next data-carousel-direction="next" aria-label="Show next demo"></button>
  </div>
</div>

<div class="image-lightbox" data-image-lightbox hidden>
  <button type="button" class="image-lightbox__close" data-image-lightbox-close aria-label="Close image zoom"></button>
  <img src="" alt="" class="image-lightbox__image" data-image-lightbox-image>
</div>
<br>

<br>
# Future directions

The current limitations outlined above are exactly what make this such an interesting and valuable problem to solve.

Some of the most exciting future directions are:

- Improve the screener model to achieve better separation between positive and negative examples, while making it more robust to variations in query phrasing, camera angle, and real-world noise.
- Move the screener closer to the source. Today, the screener is designed to run on serverless infrastructure on Modal, but over time we want it to run nearer to the camera — and eventually on-device where possible.
- Build systems that are more robust to the messiness of the real world. Real-world environments are noisy, ambiguous, and highly variable, and we want both the screening pipeline and the LLM layer to handle these variations more reliably.
- Create / curate a benchmark relevant to this problem to reliably evaluate the performance of the systems and future LLMs.
- System that can anticipate / predict events before they happen.


## Contributing

We understand that this is a highly sensitive problem, which is exactly why we believe in building it in public.If any of these directions are interesting to you, please feel free to contribute to the project or share your thoughts and feedback in github issues or join the discord channel [here](https://discord.gg/fdeCaGy5T4). You can find the code and documentation in the [GitHub repository](https://github.com/ambient-intelligence-hq/vaan).


<div class="hero-links">
  <a href="https://github.com/ambient-intelligence-hq/vaan" class="hero-links__external">GitHub</a>
  <a href="https://discord.gg/fdeCaGy5T4" class="hero-links__external">Discord</a>
</div>