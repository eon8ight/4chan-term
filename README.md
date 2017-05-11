# 4chan for your Terminal

This Perl script allows you to view 4chan threads in your terminal.

![Browsing /a/](http://i.imgur.com/9zJ67vo.png)

Current CPAN dependencies are:
* File::Fetch
* HTML::Entities
* JSON
* Readonly
* REST::Client
* Term::ANSIColor
* Term::ProgressBar
* Text::ANSITable

Additionally, `caca-utils` is required for `img2txt`.

Current commands are:
* `list boards` - List all boards.
* `list threads <board>` - List all threads for a given board.
* `view thread <board> <thread OP>` - List all posts in a thread in a given board.
* `search catalog <board> <search term>[, <search term>, ...]` - Searches a given board
  for threads with any of the search terms in their title or OP.
* `pull images <board> <thread OP> [<download location>]` - Download all images
  in a thread. If no download location is specified, a new folder with the OP
  post number is created in the current working directory and all files are
  downloaded there.
