import NIO
import NIOHTTP1
import NIOSSL

final class ProblematicHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    typealias OutboundIn = Never
    typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch self.unwrapInboundIn(data) {
        case .head(let head):
            assert(head.method == .CONNECT, "Initial HTTP method not CONNECT")
            // do not read anything else from CONNECT here
        case .body:
            break
        case .end:
            let sniHandler = ByteToMessageHandler(SNIHandler { result in
                switch result {
                case .hostname(let hostname):
                    print("SNI handler received hostname: \(hostname)")
                    return self.addSSLServer(context: context)
                case .fallback:
                    print("SNI handler did not receive hostname")
                    return self.addSSLServer(context: context)
                }
            })
            
            context.pipeline.addHandlers([sniHandler], position: .first).whenSuccess { _ in
                self.writeOK(context: context)
            }
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        context.close(promise: nil)
    }
}

extension ProblematicHandler {
    private func writeOK(context: ChannelHandlerContext) {
        print("Writing back 200 OK to CONNECT request")
        context.write(self.wrapOutboundOut(.head(.init(version: .http1_0, status: .ok))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }
    
    private func addSSLServer(context: ChannelHandlerContext) -> EventLoopFuture<Void> {
        // We need to remove and add back HTTPRequestDecoder for messages to start flowing
        context.pipeline.handler(type: ByteToMessageHandler<HTTPRequestDecoder>.self).flatMap { requestDecoder in
            context.pipeline.handler(type: ByteToMessageHandler<SNIHandler>.self).flatMap { sniHandler in
                context.pipeline.addHandlers([
                    NIOSSLServerHandler(context: sslContext),
                    ByteToMessageHandler(HTTPRequestDecoder()),
                ], position: .after(sniHandler))
                
                .flatMap { _ in
                    context.pipeline.removeHandler(requestDecoder)
                }
                .flatMap { _ in
                    context.pipeline.removeHandler(self)
                }
            }
        }
        
        /*
         * This simpler version does not work, the GET request to 127.0.0.1:8080 is not received by HelloHandler
         
        context.pipeline.handler(type: ByteToMessageHandler<SNIHandler>.self)
            .flatMap { sniHandler in
                context.pipeline.addHandlers([
                    NIOSSLServerHandler(context: sslContext)
                ], position: .after(sniHandler))
            }
            .flatMap { _ in
                context.pipeline.removeHandler(self)
            }
         */
    }
}

extension ProblematicHandler: RemovableChannelHandler {
    func removeHandler(context: ChannelHandlerContext, removalToken: ChannelHandlerContext.RemovalToken) {
        context.leavePipeline(removalToken: removalToken)
    }
}
