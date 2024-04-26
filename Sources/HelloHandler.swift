import NIO
import NIOHTTP1

final class HelloHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    typealias OutboundIn = Never
    typealias OutboundOut = HTTPServerResponsePart

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch self.unwrapInboundIn(data) {
        case .head:
            break
            
        case .body, .end:
            print("Writing back hello from HelloHandler")

            let buffer = context.channel.allocator.buffer(string: "hello")

            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok,
                                        headers: HTTPHeaders([("Content-Length", "\(buffer.readableBytes)"), ("Connection", "close")]))

            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            context.write(self.wrapOutboundOut(.body(IOData.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete { _ in
                context.close(promise: nil)
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
