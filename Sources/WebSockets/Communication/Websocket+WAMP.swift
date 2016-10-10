//
//  Websocket+WAMP.swift
//  Engine
//
//  Created by David Moeller on 10/10/2016.
//
//
// This Implementation is heavily inspired by https://github.com/iscriptology/swamp and obviously the WAMP-Protocol itself:
// https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02

import Foundation

protocol WAMP {
	
	static func connectWithWAMP(to uri: String, with realm: String) -> WebSocket
	
}

enum WAMPRole: String {
	// Client roles
	case caller = "caller"
	case callee = "callee"
	case subscriber = "subscriber"
	case publisher = "publisher"
	
	// Route roles
	case broker = "broker"
	case dealer = "dealer"
}

enum WAMPMessageType: Int {
	
	// Basic profile messages
	
	case hello = 1
	case welcome = 2
	case abort = 3
	case goodbye = 6
	
	case error = 8
	
	case publish = 16
	case published = 17
	case subscribe = 32
	case subscribed = 33
	case unsubscribe = 34
	case unsubscribed = 35
	case event = 36
	
	case call = 48
	case result = 50
	case register = 64
	case registered = 65
	case unregister = 66
	case unregistered = 67
	case invocation = 68
	case yield = 70
	
	// Advance profile messages
	case challenge = 4
	case authenticate = 5
	
}

class WAMPSession {
	
}
