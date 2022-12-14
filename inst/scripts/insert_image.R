warning2 = blogdown:::warning2

txt_input = function(..., width = '100%') shiny::textInput(..., width = width)

ctx = rstudioapi::getSourceEditorContext()
if (ctx$path == '') stop(
  'Please select the blog post source file before using this addin', call. = FALSE
)
ctx_ext = tolower(xfun::file_ext(ctx$path))

path = xfun::normalize_path(ctx$path)
path = xfun::relative_path(path)

# is this addin running inside a site or not?
is_site = !identical(blogdown:::site_root(), I('.'))

imgdir = if ((bundle <- blogdown:::bundle_index(path)) || !is_site) {
  file.path(dirname(path), 'images')
} else {
  file.path(
    'static', dirname(gsub('^content/', '', path)),
    paste0(xfun::sans_ext(basename(path)), '_files')
  )
}

shiny::runGadget(
  miniUI::miniPage(miniUI::miniContentPanel(
    shiny::fillRow(
      shiny::fileInput('newimg', 'Image', placeholder = 'Select external image'),
      shiny::column(width = 6, offset = 2, shiny::uiOutput('overbutton')),
      height = '90px'
    ),
    shiny::fillRow(
      txt_input('w', 'Width', '', '(optional) e.g., 400px or 80%'),
      txt_input('h', 'Height', '', '(optional) e.g., 200px'),
      height = '70px'
    ),
    shiny::fillRow(
      txt_input('alt', 'Alternative text', '', '(optional but recommended) e.g., awesome screenshot'),
      height = '70px'
    ),
    shiny::fillRow(
      txt_input('target', 'Target file path', '', '(optional) customize if necessary'),
      height = '70px'
    ),
    miniUI::gadgetTitleBar(NULL)
  )),
  server = function(input, output, session) {
    shiny::observeEvent(input$newimg, {
      shiny::updateTextInput(session, 'target', value = file.path(imgdir, input$newimg$name))
    })
    shiny::observeEvent(input$target, {
      output$overbutton = shiny::renderUI(if (file.exists(input$target))
        shiny::radioButtons(
          'overwrite', 'Target image exists. Overwrite it?',
          inline = TRUE, c('Yes' = TRUE, 'No' = FALSE), selected = FALSE
        )
      )
    })
    shiny::observeEvent(input$done, {
      if (is.null(input$newimg)) return(warning2('You have to choose an image!'))
      target = input$target
      if (is_site) if (bundle) {
        if (!startsWith(target, dirname(path))) return(warning2(
          "The target file path must be under the directory '", dirname(path), "'."
        ))
      } else {
        if (!grepl('^static/', target)) return(warning2(
          "The target file path must start with 'static/'."
        ))
      }
      if (file.exists(target)) {
        if (!as.logical(input$overwrite)) warning2(
          'The image already exists and you chose not to overwrite it! ',
          'Linking to the previous version of the image.'
        )
      }
      xfun:::dir_create(dirname(target))
      copy_check = file.copy(
        input$newimg$datapath, target,
        overwrite = if (is.null(input$overwrite)) FALSE else as.logical(input$overwrite)
      )
      if (copy_check) message('Successfully copied the image to ', target)

      validate_css_unit = function(x) {
        if (x == '') return(x)
        tryCatch(htmltools::validateCssUnit(x), error = function(e) {
          warning2(e$message)
          x
        })
      }
      image_code = function() {
        s = if (!is_site) {
          xfun::relative_path(target, dirname(path), error = FALSE)
        } else if (bundle) substring(target, nchar(dirname(path)) + 2) else paste0(
          ifelse(getOption('blogdown.insertimage.usebaseurl', FALSE),
            blogdown:::load_config()$baseurl, '/'),
          gsub('^static/', '', target)
        )
        w = input$w; h = input$h; alt = input$alt
        if (w == '' && h == '') {
          paste0('![', alt, '](', s, ')')
        } else {
          w = validate_css_unit(w); h = validate_css_unit(h)
          if (ctx_ext == 'rmd') paste0(
            '![', alt, '](', s, '){',
            if (w != '') paste0('width=', w),
            if (h != '') paste0(' height=', h),
            '}'
          ) else shiny::img(
            src = s, alt = alt, width = if (w != '') w, height = if (h != '') h
          )
        }
      }

      rstudioapi::insertText(as.character(image_code()), id = ctx$id)
      shiny::stopApp()
    })
    shiny::observeEvent(input$cancel, {
      shiny::stopApp()
    })
  },
  stopOnCancel = FALSE,
  viewer = shiny::dialogViewer('Add external image to a blogdown post', height = 380)
)
