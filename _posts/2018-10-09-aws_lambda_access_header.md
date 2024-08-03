---
layout: category-post
title:  "Building an AWS lambda service to return binary data (image) as a response without Access header."
date:   2018-10-09
categories: blog
---


The other day I was trying my hands at building a lambda service. As with other AWS offerings, it was not very user-friendly. Thanks to libraries like Claudia.js which made the process a little less painful. The major trouble I had was to return a binary ( image ) response from the service which can be directly used in a browser and render with the <img> tag.

So after a day of fiddling with many AWS forum, Stackoverflow suggestions. I was lucky enough to find a working solution. I wanted to write this as a post. So that it will be a reference for my future self as well as it might help someone.

**The problem :**

By default AWS documentation and [this ](https://claudiajs.com/tutorials/binary-content.html)claudia.js tutorial required me to send* “Access: image/png” *header in my GET request for it to be recognized as a binary data.

    curl --request GET -H "Accept: image/png" https://XXXXXX.execute-api.us-XXXX-1.amazonaws.com/endpoint

But this wouldn’t suit my use case of accessing it from the browser. Even though the browser by default sends multiple headers and “image” being one of the header, this was not considered by AWS API Gateway.

![Browser’s request header](https://cdn-images-1.medium.com/max/2700/1*ehSFT-c8Bkjj073jqac83A.png)*Browser’s request header*

**Solution:**

1. Ensure that you include the success parameter and isBase64Encoded as shown below in your API router.

```js

api.get('/route', function (request) {

  /* .... Body of the router */

  return data.toString("base64") // 1. route body should return response in Base64 String format.
     
},{ // <-- 2. params required for binary response.
    success: 
            { 
                contentType: 'image/png', 
                contentHandling: 'CONVERT_TO_BINARY'
            },
"isBase64Encoded": true
});

```

2. Add Mime type *“ */* ”* in the settings page of your API gateway console. This I guess enables API Gateway to consider browser’s multiple headers.

![Configuration in API Gateway](https://cdn-images-1.medium.com/max/2000/1*8yeuSQq3ZyvB1anYeEB5eg.png)*Configuration in API Gateway*

3. Deploy the API.

**One little quirk:** Whenever you deploy an update via Claudia.js, the allowed mime types in API gateway seem to reset itself. So you may have to repeat from step 2, for each update.

I have included an example lambda service to resize an image on the fly, which demonstrates all these in detail. The complete code can be found [here](https://gist.github.com/infinitylogesh/4e0f774f5f48252a767a65f75e527ccd)
