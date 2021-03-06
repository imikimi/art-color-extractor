###
TODO:
  In testing, extractColors spends about 90% of its time in Vibrant. I think 'quantize' is the problem:

  a) SPEED: I suspect quantize could be significantly optimized. It uses an array-of-arrays datastructure
    which is generally not the fastest option for JavaScript. Instead, if we wrote it to
    work directly with the Uint8ClampedArray pixel data, I suspect it would be significantly faster.

    We should be able to achieve near-c speeds.

  b) BUGFIX: When running on grayscale images, quantize produces vibrant colors!

  If we rewrite quantize, some notes:

    - https://en.wikipedia.org/wiki/Color_quantization
    - LAB color-space, or at least HSB, is probably better than RGB, but at what cost?
    - Octrees?
    - My Master's Thesis Algorithm!

  SBD Master's Thesis Applied - spacial-color-clustering

    0) convert pixels to LAB or HSB
    1) build a cluster-graph initially with every pixel in its own cluster linked to their left/right/up/down neighbors
    2) repeat until ???
        for all edges, select the one with the minimum distance between clusters
          merge those two clusters:
            color: weighted average of the two clusters' colors
            weight: cluster1.weight + cluster2.weight

    *) ??? - when to stop? Either
      a) when we are down to a certain number of clusters or
      b) when merging two clusters exceeds a certain threshold
      c) most of the image is covered by a few large clusters
        Ex: the 10 largest clusters account for 90% of the image.

    *) There should be an optional, final pass which
      a) elliminates small, unintersting clusters
      b) merges clusters which are very similar even though they are not adjacent

    *) I think we can use a HEAP structure to make this reasonably fast.
      Initially there will be n clusters and m = n * 2 edges where n == number of pixels.
      The heap contains records:
        edge-weight - euclidean-distance-squared betwen cluster's colors
        edge-cluster-a-id
        edge-cluster-b-id
      When we merge clusters, we must update the edge-weights of all their combined edges.
        - and some edges will now be duplicates, so remove them.
      The heap can just be a single floating-point array. It'll be about 32k.

      Cluster Map:
        clusterId:
          weight: int - number of pixels in the cluster
          color:  (LAB) - average color of all pixels in cluster
          centroid: (point) - average location of all pixels in cluster (optional)

      Cluster map could be a float array, too:
        weight (float)
        L, A, B: (floats)
        X, Y: (floats)

###

Vibrant    = require './Vibrant'

{log, object, merge, toPlainObjects, isString, isArray
currentSecond
} = require 'art-standard-lib'

{rgb256Color, rgbColor, point, Matrix} = require 'art-atomic'
{Bitmap} = require 'art-canvas'

defaultColorMapSize = point 3


[
  previewBitmapScale
  previewBitmapBlur
] = [10, 5] # [7, 2] # is not bad and about 30% faster, but I can see banding on the 8pmSunset image.

module.exports =
  version: version = (require '../../../package.json').version

  getColorMap: getColorMap = (bitmap, targetSize = defaultColorMapSize) ->
    b = bitmap.getMipmap targetSize
    final = bitmap.newBitmap targetSize
    final.drawBitmap Matrix.scale(targetSize.div b.size), b

    for r, i in pd = final.imageData.data by 4
      rgb256Color r, pd[i + 1], pd[i + 2]

  getColorMapBitmap: getColorMapBitmap = (colorMap) ->
    {imageData} = colorMapBitmap = new Bitmap 3
    i = 0
    {data} = imageData
    for color in colorMap
      {r256,g256,b256} = rgbColor color
      data[i + 0] = r256
      data[i + 1] = g256
      data[i + 2] = b256
      data[i + 3] = 255
      i += 4

    colorMapBitmap.putImageData imageData

  generatePreviewBitmap: generatePreviewBitmap = (colorInfo)->
    if isString(colorInfo) && colorInfo.length == 54
      colorMap = unpackColorMap colorInfo
    else if isArray(colorInfo) && colorInfo.length == 9
      colorMap = colorInfo
    else
      if colorInfo?.colorMap
        return generatePreviewBitmap colorInfo.colorMap
      throw new Error "invalid colorInfo"

    getColorMapBitmap(colorMap).scale previewBitmapScale
    .blur previewBitmapBlur

  packColorMap: (colorMap) -> colorMap.join('').replace /#/g, ''
  unpackColorMap: unpackColorMap = (colorMap) ->
    if isString colorMap
      "##{c}" for c in colorMap.match /[0-9a-f]{6}/g
    else
      colorMap


  mipmapSize: mipmapSize = 128

  getVibrantQualifyingColors: Vibrant.getVibrantQualifyingColors

  ###
  IN: bitmap

    Example:

    context = canvas.getContext '2d'
    imageData = context.getImageData 0, 0, canvas.width, canvas.height
    imageDataBuffer = imageData.data.buffer

    log extractColors imageDataBuffer

  OUT:
    version:
    colorMap: [] # 9 colors that represent the image in this shape:
      1 2 3
      4 5 6
      7 8 9
    colors: {} # named colors
  ###
  extractColors: extractColors = (bitmap, options) ->
    bitmap = bitmap.getMipmap mipmapSize
    {data} = bitmap.imageData

    startTime = currentSecond()
    out = merge
      version:    version.split(".")[0] | 0
      colorMap:   getColorMap bitmap unless options?.noColorMap
      colors:     new Vibrant(data, options).colors

    if options?.verbose
      log
        scaledBitmap: bitmap
        extractColors: out
        milliseconds: (currentSecond() - startTime) * 1000 | 0
    out

  extractColorsAsPlainObjects: (bitmap) => toPlainObjects extractColors bitmap