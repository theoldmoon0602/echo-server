import std.socket;

interface Connection {
public:
	void setSocket(Socket);
	void start();
	void recv(ubyte[] data);
	ulong send(ubyte[] data);
	void close();
}

class TCPConnection : Connection{
protected:
	Socket socket;
public:

	override void setSocket(Socket socket) {
		this.socket = socket;
	}

	override void start() {}
	
	override void recv(ubyte[] data) {
		import std.string:assumeUTF;
		string s = data.assumeUTF;
		send(cast(ubyte[])s);
	}

	override ulong send(ubyte[] data) {
		ulong sent = 0;
		while (true) {
			if (!socket.isAlive) { return sent; }
			auto l = socket.send(data);
			sent += l;
			if (l >= data.length) {
				break;
			}
			data = data[l..$];
		}
		return sent;
	}

	override void close() {
		import std.stdio;
		writeln("CLOSE");
	}
}


class TCPListener(TCPConnection) 
if (is(TCPConnection:Connection))
{
private:
	Socket listener;
	TCPConnection[] conns;
	ulong id;
public:

	void listen(ushort port) {
		this.listener = new TcpSocket();
		listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		listener.bind(new InternetAddress(port));
		listener.listen(128);

		auto socketSet = new SocketSet();
		auto errorSet = new SocketSet();
		while (true) {
			socketSet.reset();
			socketSet.add(listener);
			foreach (conn; this.conns) {
				socketSet.add(conn.socket);								
			}

			errorSet.reset();
			errorSet.add(listener);
			foreach (conn; this.conns) {
				errorSet.add(conn.socket);
			}

			// wait for event
			Socket.select(socketSet, null, errorSet);

			// accept new connection
			if (socketSet.isSet(listener)) {
				auto sock = listener.accept();
				auto conn = new TCPConnection();
				conn.setSocket(sock);
				conns ~= conn;
			}

			ulong[] rmlist;
			foreach (i, conn; this.conns) {
				// when-error 
				if (errorSet.isSet(conn.socket)) {
					conn.close();
					rmlist ~= i;
					continue;
				}

				if (socketSet.isSet(conn.socket)) {
					ubyte[1024] buf;
					 
					// error check
					auto r = conn.socket.receive(buf);
					if (r == 0 || r == Socket.ERROR) {
						conn.close();
						rmlist ~= i;
						continue;
					}
					conn.recv(buf);
				}
			}

			// remove closed connection
			import std.algorithm:remove, sort;
			foreach (i; rmlist.sort!"a > b") {
				conns = conns.remove(i);
			}
		}

	}
}


void main()
{
	auto listener = new TCPListener!TCPConnection();
	listener.listen(8888);

}
