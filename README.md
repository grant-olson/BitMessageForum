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

Although it is configured to run in your browser, it is designed to be
a local application and not a true web application.  As such, it
assumes that if you can talk to your bitmessage server, you have full
rights.

## Installation

### Prerequisites

#### Software

The following software is required:

* Ruby
* bundler
* PyBitmessage

#### PyBitmessage API configuration

To enable the API for PyBitmessage you must add the following to
the `[bitmessagesettings]` section of keys.dat:

    apienabled = true
    apiport = 8442
    apiinterface = 127.0.0.1
    apiusername = bmf
    apipassword = bmf

#### Initial installation

    git clone BM-2DAxhHpd2Sez4oQmZu5sEAMJbnNp3yDFCU
    cd BitMessageForum
    bundle install

If you are using different settings for the PyBitmessage server, you
will need to change that in `config/settings.yml`.

#### Running BMF

    cd BitMessageForum
    ./bmf

After that navigate to http://localhost:4567/

Bam!