% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hugo.R
\name{shortcode}
\alias{shortcode}
\alias{shortcode_html}
\alias{shortcodes}
\alias{shortcode_open}
\alias{shortcode_close}
\title{Helper functions to write Hugo shortcodes using the R syntax}
\usage{
shortcode(.name, ..., .content = NULL, .type = "markdown")

shortcode_html(...)

shortcodes(..., .sep = "\\n")

shortcode_open(...)

shortcode_close(...)
}
\arguments{
\item{.name}{The name of the shortcode.}

\item{...}{All arguments of the shortcode (either all named, or all unnamed).
The \code{...} arguments of all other functions are passed to
\code{shortcode()}.}

\item{.content}{The inner content for the shortcode.}

\item{.type}{The type of the shortcode: \code{markdown} or \code{html}.}

\item{.sep}{The separator between two shortcodes (by default, a newline).}
}
\value{
A character string wrapped in \code{htmltools::HTML()};
  \code{shortcode()} returns a string of the form \code{{{\% name args \%}}},
  and \code{shortcode_html()} returns \code{{{< name args >}}}.
}
\description{
These functions return Hugo shortcodes with the shortcode name and arguments
you specify. The closing shortcode will be added only if the inner content is
not empty. The function \code{shortcode_html()} is essentially
\code{shortcode(.type = 'html')}. The function \code{shortcodes()} is a
vectorized version of \code{shortcode()}. The paired functions
\code{shortcode_open()} and \code{shortcode_close()} provide an alternative
method to open and close shortcodes, which allows inner content be processed
safely by Pandoc (e.g., citation keys in the content).
}
\details{
These functions can be used in either \pkg{knitr} inline R expressions or
code chunks. The returned character string is wrapped in
\code{htmltools::\link[htmltools]{HTML}()}, so  \pkg{rmarkdown} will protect
it from the Pandoc conversion. You cannot simply write \code{{{< shortcode
>}}} in R Markdown, because Pandoc is not aware of Hugo shortcodes, and may
convert special characters so that Hugo can no longer recognize the
shortcodes (e.g. \code{<} will be converted to \code{&lt;}).

If your document is pure Markdown, you can use the Hugo syntax to write
shortcodes, and there is no need to call these R functions.
}
\note{
Since Hugo v0.60, Hugo has switched its default Markdown rendering
  engine to Goldmark. One consequence is that shortcodes may fail to render.
  You may enable the \code{unsafe} option in the configuration file:
  \url{https://gohugo.io/getting-started/configuration-markup/#goldmark}.
}
\examples{
library(blogdown)

shortcode("tweet", user = "SanDiegoZoo", id = "1453110110599868418")
# multiple tweets (id's are fake)
shortcodes("tweet", user = "SanDiegoZoo", id = as.character(1:5))
shortcode("figure", src = "/images/foo.png", alt = "A nice figure")
shortcode("highlight", "bash", .content = "echo hello world;")

shortcode_html("myshortcode", .content = "My <strong>shortcode</strong>.")

shortcode_open("figure", src = "/images/foo.png")
# This inner text will be *processed* by Pandoc, @Smith2006
shortcode_close("figure")
}
\references{
\url{https://gohugo.io/extras/shortcodes/}
}
