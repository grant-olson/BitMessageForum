     .----------------.  .----------------.  .----------------. 
    | .--------------. || .--------------. || .--------------. |
    | |   ______     | || | ____    ____ | || |  _________   | |
    | |  |_   _ \    | || ||_   \  /   _|| || | |_   ___  |  | |
    | |    | |_) |   | || |  |   \/   |  | || |   | |_  \_|  | |
    | |    |  __'.   | || |  | |\  /| |  | || |   |  _|      | |
    | |   _| |__) |  | || | _| |_\/_| |_ | || |  _| |_       | |
    | |  |_______/   | || ||_____||_____|| || | |_____|      | |
    | |              | || |              | || |              | |
    | '--------------' || '--------------' || '--------------' |
     '----------------'  '----------------'  '----------------' 

            Bit                Message             Forum

BitMessageForum allows you to browse and post bitmessages in a
forum-like view in the web browser of your choice.

Although BMF is configured to run in your browser, it is designed to
be a local application.  it assumes that if you can talk to your
bitmessage server, you are fully authorized to read/send/delete any
messages, create new identities, etc.

It is **not** designed to be setup as a publically facing website.
Although it would be possible to use the software to mirror a channel
via a web interface, this would break the self-destruct feature that
removes bitmessages from the network after a few days. So please don't
do that!

## Screenshots

<img src='./screenshots/threads.png' />

## Installation

### Prerequisites

#### Software

The following software is required:

* [Ruby](http://www.ruby-lang.org/en/)
* [bundler](http://bundler.io/)
* [PyBitmessage](https://bitmessage.org/wiki/Main_Page)

#### PyBitmessage API configuration

To enable the API for PyBitmessage you must add the following to
the `[bitmessagesettings]` section of keys.dat:

    apienabled = true
    apiport = 8442
    apiinterface = 127.0.0.1
    apiusername = bmf
    apipassword = bmf

### Initial installation

    git clone https://github.com/grant-olson/BitMessageForum.git
    cd BitMessageForum
    bundle install

If you are using different settings for the PyBitmessage server, you
will need to change that on the [settings
page](http://localhost:4567/settings/) or by manually editing
`config/settings.yml`.

### Running BMF

    cd BitMessageForum
    ./bmf

After that navigate to [http://localhost:4567/](http://localhost:4567/)

Bam!

### Running PyBitmessage as a daemon

If you find yourself using BMF all the time and don't want to see the
PyBitmessage UI, you can start PyBitmessage as a daemon.

First, add the following to the `[bitmessagesettings]` section of `keys.dat`:

    daemon = true

Next, start PyBitmessage like so:

    nohup python src/bitmessagemain.py &

This will start up PyBitmessage in the background without the QT GUI.

## Contact

Found a bug? [File an issue.](https://github.com/grant-olson/BitMessageForum/issues)

Need help?  Ask on the bmf support channel.

    * Name: bmf_support
    
    * Address: BM-2DBsnPXWVR7PbC5qMEYAdgtaSQnkr5X7ng 

Or send me a personal bitmessage: BM-2DAxhHpd2Sez4oQmZu5sEAMJbnNp3yDFCU 

Email me:  kgo at grant-olson dot net.

OpenPGP Key:

    pub   2048R/E3B5806F 2010-01-11 [expires: 2014-01-03]
          Key fingerprint = A530 C31C D762 0D26 E2BA  C384 B6F6 FFD0 E3B5 806F
    uid                  Grant T. Olson (Personal email) <kgo at grant-olson dot net>
    sub   2048R/6A8F7CF6 2010-01-11 [expires: 2014-01-03]
    sub   2048R/A18A54D6 2010-03-01 [expires: 2014-01-03]
    sub   2048R/D53982CE 2010-08-31 [expires: 2014-01-03]
