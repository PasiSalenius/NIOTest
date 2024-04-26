# NIOTest

This SwiftNIO project demonstrates an issue where we need to remove ByteToMessageHandler<HTTPRequestDecoder> and add one back to the pipeline before any messages are send to next handlers in the pipeline.

To follow the original SwiftNIO based application somewhat closely, it first listens for incoming CONNECT requests, then adds an SNIHandler to the pipeline, and after receiving a TLS ClientHello adds a SSLServerHandler to the pipeline. There is a HelloHandler at the end of the pipeline that only sends back the string `hello` and then closes the connection.

## Usage

- Run this project.
- It starts a proxy listener at http://127.0.0.1:8080.
- Connect to it using `curl --proxy http://127.0.0.1:8080 --insecure --verbose https://127.0.0.1:8080`  
- Curl logging shows that `HelloHandler` sends us back the message `hello`.
- Uncomment the alternate code in `func addSSLServer(context: ChannelHandlerContext)`, run the Curl command again and notice that `HelloHandler` does not receive a request. 
