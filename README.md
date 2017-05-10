# 4chan for your Terminal

This Perl script allows you to view 4chan threads in your terminal.

It is far from perfect.

Current dependencies are:
* File::Fetch
* HTML::Entities
* JSON
* REST::Client
* Term::ANSIColor
* Term::ProgressBar

Current commands are:
* `list boards` - List all boards.
* `list threads <board>` - List all threads for a given board.
* `view thread <board> <thread OP>` - List all posts in a thread in a given board.
* `pull images <board> <thread OP> [<download location>]` - Download all images
  in a thread. If no download location is specified, a new folder with the OP
  post number is created in the current working directory and all files are
  downloaded there.
