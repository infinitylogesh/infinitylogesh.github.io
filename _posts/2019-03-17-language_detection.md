---
layout: category-post
title:  "A Handy pre-trained model for language Identification"
date:   2019-03-17
categories: blog
---


I was trying to find solutions to gracefully handle Non-English based input to one of our deep learning-based NLP model which was trained only on English samples. Non-English words are out of vocabulary to the model, it wasn’t handling it well. Even though we wanted to make the model multi-lingual ( more on it in future posts) in the future, stumbling upon Fast text’s pre-trained language detection model was a pleasant surprise and made us consider it as an interim solution. So wanted to write a short post on it.

As a pre-requisite install the [fastText](https://github.com/facebookresearch/fastText/tree/master/python) library.

```bash

$ git clone https://github.com/facebookresearch/fastText.git
$ cd fastText
$ pip install .

```

Download the pre-trained model from [here](https://fasttext.cc/docs/en/language-identification.html). The compressed version of the model is just a little shy of 1MB and supports 176 languages. Which is an amazing work by Fast text team.

Load the model in memory using the fastText library. *Make sure the inputs are encoded in UTF-8*. *Model supports only UTF-8 as it was trained only on UTF-8 samples.*

```python

import fasttext
import sys
reload(sys)
sys.setdefaultencoding('UTF8') # default encoding to utf-8
lid_model = fastText.load_model("lid.176.ftz")

```

prediction using the loaded model.


```python

lid_model.predict("மதியும் மடந்தை முகனு மறியா பதியிற் கலங்கிய மீன்.") 
#output - ((u'__label__ta',), array([0.99988115]))
# __label__ta - tamil

lid_model.predict("Incapaz de distinguir la luna y la cara de esta chica,Las estrellas se ponen nerviosas en el cielo.")
#output - ((u'__label__es',), array([0.93954092]))
# __label__es - spanish

lid_model.predict("Unable to tell apart the moon and this girl’s face,Stars are flustered up in the sky.")
#output - ((u'__label__en',), array([0.93129086]))
#__label__en - english

```

The output is a tuple of language label and prediction confidence. Language label is a string with “__lable__” followed by ISO 639 code of the language. Full code is [here](https://github.com/infinitylogesh/language-detection-fasttext).
