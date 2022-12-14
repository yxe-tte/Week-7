#' Provide diagnostics for a website project
#'
#' The function \code{check_site()} runs all \code{check_*()} functions on this
#' page against a website project. See \sQuote{Details} for what each
#' \code{check_*()} function does.
#' @export
check_site = function() in_root({
  msg_init('Running a series of automated checks for your blogdown website project...')

  message(hrule())
  msg_okay('A successful check looks like this.')
  msg_todo('A check that needs your attention looks like this.')
  msg_next("Let's check out your blogdown site!")
  message(hrule())

  opts$set(check_site = TRUE); on.exit(opts$set(check_site = NULL), add = TRUE)

  check_config()
  check_gitignore()
  check_hugo()
  check_netlify()
  check_vercel()
  check_content()
})


#' @details \code{check_config()} checks the configuration file
#'   (\file{config.yaml} or \file{config.toml}) for settings such as
#'   \code{baseURL} and \code{ignoreFiles}.
#' @rdname check_site
#' @export
check_config = function() {
  config = load_config()
  f = find_config()
  msg_init('Checking ', f)
  okay = TRUE

  msg_next('Checking "baseURL" setting for Hugo...')
  base = index_ci(config, 'baseurl')
  if (is_example_url(base)) {
    msg_todo('Set "baseURL" to "/" if you do not yet have a domain.')
    okay = FALSE
  } else if (identical(base, '/')) {
    msg_todo('Update "baseURL" to your actual URL when ready to publish.')
    okay = FALSE
  } else if (is_domain_url(base)) {
    msg_todo('It seems you need to add a protocol (e.g., https://) to your "baseURL".')
    okay = FALSE
  } else {
    msg_okay('Found baseURL = "', base, '"; nothing to do here!')
  }

  msg_next('Checking "ignoreFiles" setting for Hugo...')
  ignore = c(
    '\\.Rmd$', '\\.Rmarkdown$', '_cache$',
    if (length(grep('/renv$', list.dirs()))) c('(^|/)renv$', 'renv\\.lock$')
  )
  if (is.null(s <- config[['ignoreFiles']])) {
    # missing field: add one
    msg_todo('Set "ignoreFiles" to ', xfun::tojson(ignore))
    okay = FALSE
  } else {
    # existing field: check
    m = !all(ignore %in% s) # check missing values
    u = '_files$' %in% s    # check unneeded values
    if (m || u) {
      if (m) msg_todo(
        'Add these items to the "ignoreFiles" setting: ',
        gsub('^\\[|\\]$', '', xfun::tojson(I(setdiff(ignore, s))))
      )
      if (u) msg_todo('Remove "_files$" from "ignoreFiles"')
      okay = FALSE
    } else {
      msg_okay('"ignoreFiles" looks good - nothing to do here!')
    }
  }

  msg_next("Checking setting for Hugo's Markdown renderer...")
  if (is.null(s <- config$markup$goldmark$renderer$unsafe) && hugo_available('0.60')) {
    h = config$markup$defaultMarkdownHandler
    if (is.null(h) || h == 'goldmark') {
      msg_next("You are using the Markdown renderer 'goldmark'.")
      config_goldmark(f, config)
      okay = FALSE
    } else if (!is.null(h)) {
      msg_next("You are using the Markdown renderer '", h, "'.")
      msg_okay('No todos now. If you install a new Hugo version, re-run this check.')
    }
  } else {
    msg_okay('All set!', if (!is.null(s)) ' Found the "unsafe" setting for goldmark.')
  }
  open_file(f, open = interactive() && !okay)
  msg_done(f)

  msg_init('Checking index.Rmd in the root directory')
  if (!file_exists('index.Rmd')) {
    msg_todo('index.Rmd is missing; create one with blogdown:::create_index().')
  } else if (!identical(rmarkdown::yaml_front_matter('index.Rmd')[['site']], 'blogdown:::blogdown_site')) {
    msg_todo('Add "site: blogdown:::blogdown_site" to the YAML header of index.Rmd.')
  } else {
    msg_okay('index.Rmd is correctly configured.')
  }
  msg_done('index.Rmd')
}

is_example_url = function(url) {
  is.character(url) && grepl(
    '^https?://(www[.])?(example.(org|com)|replace-this-with-your-hugo-site.com)/?', url
  )
}

# a URL without the http protocol
is_domain_url = function(url) {
  is.character(url) && !grepl('(^https?:)?//', url) &&
    grepl('^((?!-)[A-Za-z0-9-]{1,63}(?<!-)[.])+[A-Za-z]{2,6}(/?|/.*)$', url, perl = TRUE)
}

#' @details \code{check_gitignore()} checks if necessary files are incorrectly
#'   ignored in GIT.
#' @rdname check_site
#' @export
check_gitignore = function() {
  f = '.gitignore'
  msg_init('Checking ', f)
  if (!file_exists(f)) return(msg_todo(f, ' was not found. You may want to add this.'))

  x = read_utf8(f)
  msg_next('Checking for items to remove...')
  x1 = c('*.html', '*.md', '*.markdown', 'static', 'config.toml', 'config.yaml')
  if (any(i <- x %in% x1)) msg_todo(
    'Remove items from ', f, ': ', paste(x[i], collapse = ', ')
  ) else msg_okay('Nothing to see here - found no items to remove.')

  msg_next('Checking for items to change...')
  # do not ignore these folders recursively (need to add a leading slash)
  x2 = c('blogdown', 'public', 'public/', 'resources')
  if (any(i <- x %in% x2)) msg_todo(
    'Change items in ', f, ': ', paste(sprintf('%s -> /%s', x[i], x[i]), collapse = ', ')
  ) else msg_okay('Nothing to see here - found no items to change.')

  msg_next('Checking for items you can safely ignore...')
  x3 = c('.DS_Store', 'Thumbs.db', if (hugo_available('0.89.0')) '.hugo_build.lock')
  if (any(i <- x %in% x3))
    msg_okay('Found! You have safely ignored: ', paste(x[i], collapse = ', '))
  x4 = setdiff(x3, x)
  if (length(x4)) msg_todo('You can safely add to ', f, ': ', paste(x4, collapse = ', '))

  if (file_exists('netlify.toml')) {
    msg_next('Checking for items to ignore if you build the site on Netlify...')
    x5 = c('/public/', '/resources/')
    if (any(i <- x %in% x5))
      msg_okay('Found! You have safely ignored: ', paste(x[i], collapse = ', '))
    x6 = setdiff(x5, x)
    if (length(x6)) {
      msg_todo(
        'When Netlify builds your site, you can safely add to ', f, ': ',
        paste(x6, collapse = ', ')
      )
    }
  }

  if (Sys.which('git') != '' && system2_quiet('git', 'status') == 0) {
    msg_next('Checking for files required by blogdown but not committed...')
    # currently only one but may have more in future
    x7 = c('layouts/shortcodes/blogdown/postref.html')
    x8 = NULL
    for (i in x7) {
      if (!file_exists(i)) next
      if (system2_quiet('git', c('ls-files', '--error-unmatch', i)) != 0)
        x8 = c(x8, i)
    }
    if (n <- length(x8)) {
      msg_todo(
        'Found ', n, ' file', if (n > 1) 's', ' that should be committed in GIT:\n\n',
        indent_list(x8)
      )
    } else {
      msg_okay('Great! Did not find such files.')
    }
  }

  msg_done(f)
}

config_goldmark = function(f, cfg = list(), silent = FALSE) {
  x = switch(
    ext <- xfun::file_ext(f),
    yaml = '
markup:
  goldmark:
    renderer:
      unsafe: true
',
    toml = '
[markup]
  [markup.goldmark]
    [markup.goldmark.renderer]
      unsafe = true
'
  )
  if (is.null(x)) return()
  m = ext == 'yaml' && 'markup' %in% names(cfg)  # merge or append?
  if (!silent) msg_todo(
    'Allow goldmark to render raw HTML by adding this setting to ', f,
    ' (see https://github.com/rstudio/blogdown/issues/447 for more info):\n', x,
    if (m) c(
      '\nNote that the "markup" key already exists, so you have to merge the ',
      'above goldmark setting into the existing "markup" key instead of appending ',
      'it to the end of the file.'
    )
  )
  if (!m && (silent || yes_no("Do you want blogdown to set this for you?"))) {
    cat(x, file = f, append = TRUE)
  }
}

#' @details \code{check_hugo()} checks possible problems with the Hugo
#'   installation and version.
#' @rdname check_site
#' @export
check_hugo = function() {
  if (generator() != 'hugo') return()
  msg_init('Checking Hugo')
  msg_next('Checking Hugo version...')
  # current version and all possible versions of Hugo
  cv = hugo_version()
  av = find_hugo("all", quiet = TRUE)

  # if no Hugo versions are installed
  if ((n <- length(av)) == 0) return(msg_todo(
    'Hugo not found - use blogdown::install_hugo() to install.'
  ))

  msg_okay(sprintf(
    'Found %sHugo. You are using Hugo %s.', if (n > 1) paste(n, 'versions of ') else '', cv
  ))

  msg_next('Checking .Rprofile for Hugo version used by blogdown...')

  # .Rprofile exists + most recent Hugo
  if (!(is.null(sv <- get_option('blogdown.hugo.version')))) {
    msg_okay(sprintf('blogdown is using Hugo %s to build site locally.', sv))
  } else {
    msg_next('Hugo version not set in .Rprofile.')
    if (!file_exists('.Rprofile'))
      msg_todo('Use blogdown::config_Rprofile() to create .Rprofile for the current project.')
    msg_todo(sprintf('Set options(blogdown.hugo.version = "%s") in .Rprofile and restart R.', cv))
  }

  if (file_exists('netlify.toml') && !isTRUE(opts$get('check_site'))) msg_todo(
    'Also run blogdown::check_netlify() to check for possible problems with Hugo and Netlify.'
  )

  msg_done('Hugo')
}

#' @details \code{check_netlify()} checks the Hugo version specification and the
#'   publish directory in the Netlify config file \file{netlify.toml}.
#'   Specifically, it will check if the local Hugo version matches the version
#'   specified in \file{netlify.toml} (in the environment variable
#'   \var{HUGO_VERSION}), and if the \var{publish} setting in
#'   \file{netlify.toml} matches the \var{publishDir} setting in Hugo's config
#'   file (if it is set).
#' @rdname check_site
#' @export
check_netlify = function() {
  msg_init('Checking netlify.toml...')
  if (!file.exists(f <- 'netlify.toml')) return(
    if (file.exists('vercel.json')) msg_okay(
      'Found vercel.json. You are assumed to be using Vercel instead of Netlify.'
    ) else msg_todo(
      f, ' was not found. Use blogdown::config_netlify() to create file.'
    )
  )
  cfg = find_config()
  x = read_toml(f)
  v = x$context$production$environment$HUGO_VERSION
  if (is.null(v)) v = x$build$environment$HUGO_VERSION

  okay = check_versions(f, v)

  msg_next('Checking that Netlify & local Hugo publish directories match...')
  if (!is.null(p1 <- x$build$publish)) {
    p2 = publish_dir(tmp = FALSE, default = NULL)
    if (p3 <- is.null(p2)) p2 = 'public'
    if (!identical(p2, gsub('/$', '', p1))) {
      msg_next(
        'Mismatch found:\n',
        '  The Netlify "publish" directory in "', f, '" is "', p1, '".\n',
        '  The local Hugo "publishDir" directory is "', p2,
        '" (', if (p3) "Hugo's default" else c('as set in ', cfg), ').'
      )
      msg_todo('Open ', f, ' and under [build] set publish = "', p2, '".')
      okay = FALSE
    } else {
      msg_okay('Good to go - blogdown and Netlify are using the same publish directory: ', p2)
    }
  }
  open_file(f, interactive() && !okay)
  msg_done(f)
}

# check if hugo versions in config file and system match
check_versions = function(f, v, v2 = as.character(hugo_version())) {
  if (is.null(v)) {
    msg_next('HUGO_VERSION not found in ', f, '.')
    nm = switch(f, 'netlify.toml' = 'netlify', 'vercel.json' = 'vercel')
    msg_todo(
      'Set HUGO_VERSION = ', v2, ' in [build] context of ', f, '.',
      if (length(nm)) c(' See blogdown::config_', nm, '(NULL) for example.')
    )
    return(FALSE)
  }
  msg_okay('Found HUGO_VERSION = ', v, ' in [build] context of ', f, '.')
  msg_next('Checking that remote & local Hugo versions match...')
  if (v2 == v) {
    msg_okay(
      "It's a match! Local and remote Hugo versions are identical (", v2, ")."
    )
    return(TRUE)
  }
  msg_next(
    'Mismatch found:\n',
    '  blogdown is using Hugo version (', v2, ') to build site locally.\n',
    '  ', f, ' is using Hugo version (', v, ') to build site.'
  )
  msg_todo(
    'Option 1: Change HUGO_VERSION = "', v2, '" in ', f, ' to match local version.'
  )
  msg_todo(
    'Option 2: Use blogdown::install_hugo("', v, '") to match the version in ', f, ', ',
    'and set options(blogdown.hugo.version = "', v, '") in .Rprofile to pin ',
    'this Hugo version (also remember to restart R).'
  )
  FALSE
}

#' @details \code{check_vercel()} checks if the Hugo version specified in
#'   \file{vercel.json} (if it exists) matches the Hugo version used in the
#'   current system.
#' @rdname check_site
#' @export
check_vercel = function() {
  if (!file.exists(f <- 'vercel.json')) return()
  msg_init('Checking ', f, '...')
  x = jsonlite::fromJSON(f, simplifyVector = FALSE)
  v = x$build$env$HUGO_VERSION
  okay = check_versions(f, v)
  open_file(f, interactive() && !okay)
  msg_done(f)
}

#' @details \code{check_content()} checks for possible problems in the content
#'   files. First, it checks for the validity of YAML metadata of all posts.
#'   Then it searches for posts with future dates and draft posts, and lists
#'   them if found (such posts appear in the local preview by default, but will
#'   be ignored by default when building the site). Then it checks for R
#'   Markdown posts that have not been rendered, or have output files older than
#'   the source files, and plain Markdown posts that have \file{.html} output
#'   files (which they should not have). At last, it detects \file{.html} files
#'   that seem to be generated by clicking the Knit button in RStudio with
#'   \pkg{blogdown} < v0.21. Such \file{.html} files should be deleted, since
#'   the Knit button only works with \pkg{blogdown} >= v0.21.
#' @rdname check_site
#' @export
check_content = function() {
  msg_init('Checking content files')

  msg_next('Checking for validity of YAML metadata in posts...')
  meta = scan_yaml(warn = FALSE)
  files = unlist(lapply(meta, function(m) {
    if (!is.null(s <- attr(m, 'yaml_error')$message)) return(s)
    if (length(m) && !is.list(m)) return('YAML metadata is not a list')
  }))
  if (length(files)) {
    msg_todo(
      'Found invalid YAML metadata in the following files:\n\n',
      indent_list(paste0(names(files), ' (Reason: ', files, ')')),
      '\n\n  Please fix the YAML metadata of these files.'
    )
  } else {
    msg_okay('All YAML metadata appears to be syntactically valid.')
  }

  detect = function(field, fun) names(unlist(lapply(
    meta, function(m) if (is.list(m)) fun(m[[field]])
  )))

  msg_next('Checking for previewed content that will not be published...')
  files = detect('date', function(d) tryCatch(
    if (isTRUE(as.Date(d) > Sys.Date())) TRUE, error = function(e) NULL
  ))
  if (length(files)) {
    msg_todo(
      'Found ', n <- length(files), ' file', if (n > 1) 's',
      ' with a future publish date:\n\n', indent_list(files), '\n\n',
      "  If you want to publish today, change a file's YAML key to 'date: ",
      format(Sys.Date(), '%Y-%m-%d'), "'"
    )
  } else {
    msg_okay('Found 0 files with future publish dates.')
  }

  files = detect('draft', function(d) if (isTRUE(d)) TRUE)
  if (length(files)) {
    msg_todo(
      'Found ', n <- length(files), ' file', if (n > 1) 's',
      ' marked as drafts. To un-draft, run the command:\n\n',
      action_list(files, 'blogdown::edit_draft'), '\n\n',
      "  and change a file's YAML from 'draft: true' to 'draft: false' or delete it"
    )
  } else {
    msg_okay('Found 0 files marked as drafts.')
  }

  if (build_method() != 'custom') {
    msg_next('Checking your R Markdown content...')
    check_rmds()
  }

  msg_next('Checking for .html/.md files to clean up...')
  if (n <- length(files <- list_duplicates())) {
    msg_todo(
      'Found ', n, ' duplicate output file', if (n > 1) 's', ':\n\n', indent_list(files),
      '\n\n  To fix, run blogdown::clean_duplicates(preview = FALSE).'
    )
  } else {
    msg_okay('Found 0 duplicate .html output files.')
  }
  check_garbage_html()

  msg_next("Checking for the unnecessary 'content/' directory in theme...")
  if (length(d <- file.path(theme_dir(), 'content')) && dir_exists(d)) {
    msg_todo(
      'Found one! You may delete it unless it was created by you. Run:\n\n',
      '  unlink("', d, '", recursive = TRUE)\n'
    )
  } else {
    msg_okay('Great! Your theme does not contain the content/ directory.')
  }
  msg_done('Content')
}

check_rmds = function() {
  rmds = list_rmds()
  if (length(files <- filter_newfile(rmds))) {
    msg_todo(
      'Found ', n <- length(files), ' R Markdown file', if (n > 1) 's',
      ' to render:\n\n', indent_list(files), '\n\n',
      "  To render a file, knit or use blogdown::build_site(build_rmd = 'newfile')"
    )
  } else {
    msg_okay('All R Markdown files have been knitted.')
  }

  files = setdiff(rmds, files)
  files = files[require_rebuild(output_file(files), files)]
  if (length(files)) {
    msg_todo(
      'Found ', n <- length(files), ' R Markdown file', if (n > 1) 's',
      ' to update by re-rendering:\n\n', indent_list(files), '\n\n',
      "  To update a file, re-knit or use blogdown::build_site(build_rmd = 'timestamp')"
    )
  } else {
    msg_okay('All R Markdown output files are up to date with their source files.')
  }
}

#' Open a list of draft posts
#'
#' If a file is opened in RStudio, this function will try to locate the
#' \code{draft} field in YAML automatically, so you can edit this field
#' immediately.
#' @param files A vector of file paths.
#' @export
#' @keywords internal
edit_draft = function(files) {
  # edit Rmd source files before editing their output files to make sure
  # modification time of Rmd is older than output
  i = grepl(rmd_pattern, files)
  # when in RStudio, open .md before .Rmd, so users can edit .Rmd first (they
  # see the latterly opened files first)
  if (is_rstudio()) i = !i
  files = c(files[i], files[!i])
  # open files one by one
  for (f in files) {
    n = grep('^draft:', read_utf8(f))
    open_file(f, TRUE, if (length(n) == 0) -1L else n[1])
  }
}

list_duplicates = function() in_root({
  # .md/.markdown should not have .html output files
  x1 = with_ext(list_rmds(pattern = '[.](md|markdown)$'), 'html')
  # due to the bug #568, foo.html could be left behind when foo.Rmd is moved to
  # foo/index.Rmd; the leftover foo.html should be deleted
  x2 = paste0(dirname(list_rmds(pattern = paste0('^index', rmd_pattern))), '.html')
  x2 = x2[!file_exists(with_ext(x2, 'Rmd'))]
  x = c(x1, x2)
  x = sort(x[file_exists(x)])
})

#' Clean duplicated output files
#'
#' For an output file \file{FOO.html}, \file{FOO.md} should be deleted if
#' \file{FOO.Rmd} exists, and \file{FOO.html} should be deleted when
#' \file{FOO.Rmarkdown} exists (because \file{FOO.Rmarkdown} should generate
#' \file{FOO.markdown} instead) or neither \file{FOO.Rmarkdown} nor
#' \file{FOO.Rmd} exists (because a plain Markdown file should not be knitted to
#' HTML).
#' @param preview Whether to preview the file list, or just delete the files. If
#'   you are sure the files can be safely deleted, use \code{preview = FALSE}.
#' @export
#' @return For \code{preview = TRUE}, a logical vector indicating if each file
#'   was successfully deleted; for \code{preview = FALSE}, the file list is
#'   printed.
clean_duplicates = function(preview = TRUE) in_root({
  x = list_duplicates()
  x1 = with_ext(x, 'Rmd');       i1 = file_exists(x1)
  x2 = with_ext(x, 'Rmarkdown'); i2 = file_exists(x2)
  x = c(
    # if .Rmd exists using 'html' method then delete '.md'
    # if .Rmd exists using using 'markdown' method, deletes html
    with_ext(x[i1], if (build_method() == 'markdown') 'html' else 'md'),
    # if .Rmd does not exist or .Rmarkdown exists, delete html
    x[i2 | !i1]
  )
  x = x[file_exists(x)]
  if (length(x)) {
    if (preview) msg_cat(
      'Found possibly duplicate output files. Run blogdown::clean_duplicates(preview = FALSE)',
      ' if you are sure they can be deleted:\n\n', indent_list(x), '\n'
    ) else {
      file.remove(x)
      clean_html_deps(x)
    }
  } else {
    msg_cat('No duplicated output files were found.\n')
  }
})

# delete unused HTML dependencies like header-attrs (#632)
clean_html_deps = function(x) {
  x = grep('[.]html$', x, value = TRUE)
  if (length(x) == 0) return()
  x = file.path(paste0(xfun::sans_ext(x), '_files'), 'header-attrs')
  unlink(x, recursive = TRUE)
  # delete empty *_files directories
  for (d in dirname(x)) del_empty_dir(d)
}

check_garbage_html = function() {
  res = unlist(lapply(list_files('.', '[.]html$'), function(f) {
    if (file.size(f) < 200000) return()
    x = readLines(f, n = 15)
    if (any(x == '<meta name="generator" content="pandoc" />')) return(f)
  }))
  res = sub('^[.]/', '', res)
  ok = TRUE
  i = xfun::is_sub_path(res, content_file())
  if (n <- sum(i)) {
    msg_todo(
      'Found ', n, ' incompatible .html file', if (n > 1) 's',
      ' in the content directory:\n\n', action_list(res[i]), '\n\n',
      '  To fix, run the above command and then blogdown::build_site(build_rmd = "newfile").'
    )
    ok = FALSE
  }
  i = xfun::is_sub_path(res, p <- publish_dir())
  if (n <- sum(i) && any(i1 <- file_exists(f1 <- with_ext(res[i], 'Rmd')))) {
    i2 = file_exists(f2 <- content_file(substr(f1[i1], nchar(p) + 1, nchar(f1))))
    if (n <- sum(i2)) {
      msg_todo(
        'Found ', n, ' incompatible .html file', if (n > 1) 's',
        ' in the publish directory:\n\n', action_list(c(res[i][i1][i2], f1[i1])), '\n\n',
        '  To fix, restart R, run the above command, fix other issues identified ',
        'by blogdown::check_site(), and then run blogdown::build_site().'
      )
      ok = FALSE
    }
  }
  if (ok) msg_okay('Found 0 incompatible .html files to clean up.')
}
