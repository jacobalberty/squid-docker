# squid-docker
This is a squid (http://www.squid-cache.org/) docker image

## Notes about development

This container is under heavy development at the moment. I do use it in production but at this point it is tailored
to my own use. I am actively working to get it generalized enough to be useful for other people. This section contains
notes about planned changes and how things work (Or don't work).

### Configuration files
At this point configuration files just go under `/conf`. I intend to make this a little more nested to allow some of the other
features to be implemented.

### Dependencies
This image contains all of the default authentication handlers and options from the debian defaults for squid. But it does not include
all of those authentication handlers dependencies. I have plans for a special conf file just for the image that will allow you to add
dependencies that are specific to your setup without having to modify the image itself.


## Usage

Simply put your squid configuration in /conf with squid.conf located there as well.

