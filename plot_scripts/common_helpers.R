get_text_color
<-

  function
(
  fill_color
)

  {

  rgb_vals
  <-
    col2rgb
  (
    fill_color
  )

  luminance
  <-

    (
      0.299

      *
        rgb_vals
      [
        1
      ]

      +

        0.587

      *
        rgb_vals
      [
        2
      ]

      +

        0.114

      *
        rgb_vals
      [
        3
      ]
    )

  /

    255

  ifelse
  (
    luminance
    <

      0.5
    ,

    "white"
    ,

    "black"
  )

}

