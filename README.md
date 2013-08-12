

![Raphaelios - A collection of build scripts for adding iOS support to useful libraries](http://f.cl.ly/items/1B2i0e0h062M32100r3X/raphaelios_github_header.png)

Raphaelios is a collection of build scripts for adding iOS support to useful libraries.

Building fresh copies of C libraries with iOS support can be a lot of hassle. Raphaelios tries to make this easier by providing a go-to place for drop-in scripts that need little configuration.

## Example usage with openssl

- Download the ```openssl``` source ([http://www.openssl.org/source/](http://www.openssl.org/source/))
- Download ```build-openssl.sh``` and place it in the same directory as the source ([https://github.com/Raphaelios/raphaelios-scripts/blob/master/openssl/build-openssl.sh](https://github.com/Raphaelios/raphaelios-scripts/blob/master/openssl/build-openssl.sh))
- Run ```build-openssl.h```
- Include the resulting .a files in your XCode project
- Set the ```Header Search Paths``` to look for the newly created header files
- You're done!

As a quick alternative, you can give the example project a try [https://github.com/Raphaelios/raphaelios-openssl-example](https://github.com/Raphaelios/raphaelios-openssl-example) 

![Raphaelios embedding openssl in iOS app example](http://f.cl.ly/items/3D2t0x1Y1Y0D142G3c0a/raphaelios_openssl_example_xcode.png)


## Requirements

- XCode Command Line Tools ([http://developer.apple.com/downloads/](http://developer.apple.com/downloads/))
- perl

## Contact

Claudiu-Vlad Ursache

- [https://github.com/ursachec](https://github.com/ursachec)
- [https://twitter.com/ursachec](https://twitter.com/ursachec)
- [http://cvursache.com](http://cvursache.com)

## License

Raphaelios is available under the MIT license. See the LICENSE file for more info. 
