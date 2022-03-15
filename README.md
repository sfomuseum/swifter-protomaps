# SwifterProtomaps

Swift package providing methods for serving Protomaps tile databases from [httpswift/swifter](https://github.com/httpswift/swifter) instances.

## Motivation

This package provides a simple `ServeProtomapsTiles` helper method to serve one or more Protomaps tile databases using HTTP `Range` header requests, inclusive of setting any necessary `CORS` headers.

It was designed for use with an iOS application built around `WKWebKitView` views whose HTML/JavaScript code need to load and render local (on device) Protomaps tiles.

It is not designed to be a general purpose function for serving files using HTTP `Range` requests.

## Example

```
import Swifter
import SwifterProtomaps

do {
            
	guard let root = URL(string: "/path/to/pmtiles") else {
		raise NSException(name:"InvalidURL", reason:"Invalid URL", userInfo:nil).raise()
	}
	
	let port: in_port_t  = 9000
	            
	let opts = ServeProtomapsOptions(root: root)
	opts.AllowOrigins = "*"
	opts.AllowHeaders = "*"
    
	let server = HttpServer()

	server["/pmtiles/:path"] = ServeProtomapsTiles(root)
	try server.start(port)
	
} catch {
	print("Server start error: \(error)")
}
```

And then in your JavaScript code load and use Protomaps as usual, pointing to the server running on `localhost:9000`:

```
        const p = new protomaps.PMTiles("http://localhost:9000/pmtiles/example.pmtiles");
        
        p.metadata().then(m => {
            
            let bounds_str = m.bounds.split(',')
            let bounds = [[+bounds_str[1],+bounds_str[0]],[+bounds_str[3],+bounds_str[2]]]
            
            layer = new protomaps.LeafletLayer({
	            attribution: '',
        	    url:p ,
	            bounds: bounds,
            });
            

            layer.addTo(map);
        });
    }
```

## Swift Package Manager

Add the following entries to your `dependencies` block and any relevant `target` blocks.

```
dependencies: [
    	.package(url: "https://github.com/sfomuseum/swift-protomaps.git", from: "0.0.1"),
]
```

```
.target(
	name: "{YOUR_TARGET}",
	dependencies: [
		.product(name: "SwifterProtomaps", package: "swifter-protomaps")
	]
)
```

## Notes

This package requires:

* iOS 13.4 or higher
* MacOS 10.15.4 or higher.

## See also

* https://github.com/httpswift/swifter
* https://github.com/protomaps/
