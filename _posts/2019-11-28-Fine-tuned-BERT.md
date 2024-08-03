---
layout: category-post
title:  "What does a Fine-tuned BERT model look at ?."
date:   2019-11-28
categories: writing
---


An attempt to understand features and patterns learnt by a Fine-tuned BERT model

![Photo by [Katarzyna Pe](https://unsplash.com/@kasiape?utm_source=medium&utm_medium=referral) on [Unsplash](https://unsplash.com?utm_source=medium&utm_medium=referral)](https://cdn-images-1.medium.com/max/7286/0*ToC_4We3OR9cC51L)

<p style="font-size: medium;">
      <em>
        Photo by <a href="https://unsplash.com/@kasiape?utm_source=medium&utm_medium=referral">Katarzyna Pe</a> on <a href="https://unsplash.com?utm_source=medium&utm_medium=referral">Unsplash</a>
      </em>
    </p>

<p style="font-size: medium;"><em>*Note: This content was part of my talk at Analytics Vidhya’s DataHack Summit 2019.*</em></p>

There is a lot of buzz around NLP of late, especially after the advancement in transfer learning techniques and with the advent of architectures like transformers. As someone from the applied side of Machine learning, I feel that it is not only important to have models that can surpass the state of the art results in many benchmarks, It is also important to have models that are trustable, understandable and not a complete black box.

This post is an attempt to understand the learnings of BERT on task-specific training. Let’s start with how attention is implemented in a Transformer and how it can be leveraged for understanding the model ( Feel free to skip this section if you are already aware of it).

## Attention! Attention!

Transformers use self-attention to encode the representation of its input sequences at each layer. With self-attention, All the words in the input sequence contribute to the representation ( encoding ) of the current token.

Let’s consider this example from [Jalammar’s Blog](http://jalammar.github.io/illustrated-transformer/) ( I would highly recommend reading his blog post for a deeper understanding of transformers ). Here you could see that the representation of the word “Thinking” ( Z1 ) is formed by the contribution from other words in the sentence ( in this case “Machines”). The strength of the contribution of each word to the current word is determined by the attention scores ( Softmax scores ). It is similar to each word giving a part of itself to form a full representation of the current word.

![Source: [http://jalammar.github.io/illustrated-transformer/](http://jalammar.github.io/illustrated-transformer/)](https://cdn-images-1.medium.com/max/2000/1*CHuDH2Ivg-RSnBu_ZGUw8A.png)*Source: [http://jalammar.github.io/illustrated-transformer/](http://jalammar.github.io/illustrated-transformer/)*

The strength could be inferred as the semantic association of the words in the sentence to the current word. For example, the word “it” in the below visualization of an attention layer in a transformer, has a higher contribution from the words “The animal”. This could be inferred as a coreference resolution of the word “it”. This behaviour is what gives the transformers contextual representations/encodings.

![Inferring association between tokens using attention. source: [http://jalammar.github.io/illustrated-transformer/](http://jalammar.github.io/illustrated-transformer/)](https://cdn-images-1.medium.com/max/2000/1*oQPfFrzu2E590NrFkELbSA.png)*Inferring association between tokens using attention. source: [http://jalammar.github.io/illustrated-transformer/](http://jalammar.github.io/illustrated-transformer/)*

These contribution strengths (attention scores) can be leveraged to understand the association between the tokens and thereby it can also be used to understand the learnings of the transformers. This is exactly what we are going to attempt in this post. We will try to understand the task-specific features learned by the transformer.

## Task-specific features :

The paper — [What does BERT look at ?](https://arxiv.org/abs/1906.04341) (Clark et al., 2019) which got published earlier this year talks about the various linguistic and coreference patterns that are self-learned by a BERT model. Illustrating how syntax-sensitive behaviour can emerge from self-supervised training alone. This made me curious and wanted to try doing a similar study on task-specific features that BERT learn, after finetuning on a task.

![Example of Aspect based sentiment analysis — Source: [https://medium.com/seek-blog/your-guide-to-sentiment-analysis-344d43d225a7](https://medium.com/seek-blog/your-guide-to-sentiment-analysis-344d43d225a7)](https://cdn-images-1.medium.com/max/2000/1*QC9wifukkN7mTTpPlze2kg.png)*Example of Aspect based sentiment analysis — Source: [https://medium.com/seek-blog/your-guide-to-sentiment-analysis-344d43d225a7](https://medium.com/seek-blog/your-guide-to-sentiment-analysis-344d43d225a7)*

### The Task at hand :

The finetuning task that we would be using here is an [Aspect-Based sentiment analysis](https://monkeylearn.com/blog/aspect-based-sentiment-analysis/) task designed as a question answering / multi-class classification problem. This approach is inspired by this [paper](https://arxiv.org/pdf/1903.09588v1.pdf) (Sun et al.,2019). With this approach of converting the sentiment dataset into question-answer pairs (as shown below ), the authors were able to achieve state of the art results on SEMEVAL [dataset](http://alt.qcri.org/semeval2014/).

![Aspect-based sentiment analysis as QA — [https://arxiv.org/pdf/1903.09588v1.pdf](https://arxiv.org/pdf/1903.09588v1.pdf)](https://cdn-images-1.medium.com/max/3008/1*sKomk2sUs90Uzk_XxIjjWw.png)*Aspect-based sentiment analysis as QA — [https://arxiv.org/pdf/1903.09588v1.pdf](https://arxiv.org/pdf/1903.09588v1.pdf)*

I have finetuned a BERT-base-uncased model on SEMEVAL 2014 dataset using huggingface’s [transformers](https://github.com/huggingface/transformers) library and visualized the attention maps using [bertviz](https://github.com/jessevig/bertviz).

## Task-specific learnings :

Here I list a few of the interesting patterns that I observed by probing attention layers of the fine-tuned BERT model,

1. ***Aspect heads — Aspect word understanding*** :

I observed that head 9-8 mostly attends to the aspect related words in the review, that correspond to the aspect in the question ( word “service” in the below pictures gets a very high attention score from the word “waiter”). The aspect word in question (left side) in most cases have a higher contribution from the aspect word in the review ( right side ). So this could be considered to act as an aspect head.

![](https://cdn-images-1.medium.com/max/2924/1*tE3OqQJ459bG9OpcVQv09w.png)

![](https://cdn-images-1.medium.com/max/2000/1*phFGXjQcWzVkIXLjRyRowg.png)

***2. Aspect-sentiment heads — Aspect word and related sentiment words understanding :***

Here we can see examples of head 9-0 mostly focusing on aspects words that are related to the question and their corresponding sentiment words.

![](https://cdn-images-1.medium.com/max/3272/1*MVMLwoachy_URr46NXfhfw.png)

![](https://cdn-images-1.medium.com/max/2000/1*8MGfWQOaPcrv1kFvkN_uQw.png)

***3. Phrase level attention to aspect and sentiments :***

I also observed that there are heads that focus on the complete phrase in a review that talks about the relevant aspect in the question.

![](https://cdn-images-1.medium.com/max/3232/1*NZ4HK28r09zc8r6bYbCt2w.png)

![](https://cdn-images-1.medium.com/max/2000/1*z5k_sU1cRThdr_Vhqk5Uiw.png)

***4. Attending to the opposite aspect :***

Surprisingly, the head 10–3 was focussing mostly on the other aspect and their related words that are not available in the question. Here we can see when the aspect in question is “service”, head focuses on “food” related words and vice-versa.

![](https://cdn-images-1.medium.com/max/3284/1*5n32IasWYtZiYagDMGQ-bA.png)

![](https://cdn-images-1.medium.com/max/2000/1*QS8SMmYfT6pWmO4JghpxFg.png)

***5. Absence of the interested aspect in the review — No-OP:***

When there is no mention of a given aspect in the review. Head focuses on [SEP] token. As a way of indicating the feature absence (No-Op), The heads that are designated to extract the absent feature focus on [SEP] token. This observation is in line with the findings of the paper — [what does BERT look at?](https://arxiv.org/pdf/1906.04341.pdf) (Clark et al., 2019).

![](https://cdn-images-1.medium.com/max/3280/1*dyNXwNXK5cN9iSuO71gH4g.png)

## Further steps :

1. Even though the heads that we have seen till now attend to the specified features in most cases, there are also examples where the heads don’t attend to those expected features. So, it would be really interesting to do a more formal study ( by measuring the accuracy of individual heads, similar to Clark et al., 2019 ) on each head and their ability to attend to the hypothetical feature.

## Code:

1. Task-Specific learnings — [https://colab.research.google.com/drive/1P4HWHso-bV5vW8pKDSqPERet507KGlr3](https://colab.research.google.com/drive/1P4HWHso-bV5vW8pKDSqPERet507KGlr3)

1. Linguistic and syntactic learning — Replicating the results of Clark et al.2019 — [https://colab.research.google.com/drive/1z5W-JGtYBFfbIWZbIO73z0oIWtEFZJYO](https://colab.research.google.com/drive/1z5W-JGtYBFfbIWZbIO73z0oIWtEFZJYO)

1. Slides of my talk at DHS 2019 — [https://github.com/infinitylogesh/Interpretable-NLP-Talk](https://github.com/infinitylogesh/Interpretable-NLP-Talk)

## ***References :***

1. Kevin Clark, Urvashi Khandelwal, Omer Levy and Christopher D. Manning, [What Does BERT Look At? An Analysis of BERT’s Attention](https://arxiv.org/abs/1906.04341) (2019).

1. [The illustrated transformer](http://jalammar.github.io/illustrated-transformer/)

1. Huggingface’s [transformer](https://github.com/huggingface/transformers) library

1. [BertViz](https://github.com/jessevig/bertviz).
