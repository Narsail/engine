//
//  WAMPMessageType.swift
//  Engine
//
//  Created by David Moeller on 12/10/2016.
//
// This Implementation is heavily inspired by https://github.com/iscriptology/swamp and obviously the WAMP-Protocol itself:
// https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02

import Foundation
import Jay

public protocol WAMPMessage {
	init(payload: [Any]) throws
	func marshal() -> [Any]
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

enum WAMPMessageError: Error {
	case realmNotFound
	case sessionIDnotFound
	case detailsNotFound
	case reasonNotFound
	case wrongMessageType(payload: Int)
	case noPayloadArrayFound
	case wrongPayloadType
	case messageTypeNotImplemented(type: WAMPMessageType)
}

// MARK: - Session Messages

// MARK: Hello Message

/// [HELLO, realm|string, details|dict]
class HelloMessage: WAMPMessage {
	
	let realm: String
	let details: [String: Any]
	
	init(realm: String, details: [String: Any]) {
		self.realm = realm
		self.details = details
	}
	
	// MARK: SwampMessage protocol
	
	required convenience init(payload: [Any]) throws {
		
		guard let realm = payload[0] as? String else { throw WAMPMessageError.realmNotFound }
		guard let details = payload[1] as? [String: Any] else { throw WAMPMessageError.detailsNotFound }
		
		self.init(realm: realm, details: details)
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.hello.rawValue, self.realm, self.details]
	}
}

// MARK: Welcome Message

/// [WELCOME, sessionId|number, details|Dict]
class WelcomeMessage: WAMPMessage {
	
	let sessionId: Int
	let details: [String: Any]
	
	init(sessionId: Int, details: [String: Any]) {
		self.sessionId = sessionId
		self.details = details
	}
	
	required convenience init(payload: [Any]) throws {
		
		guard let sessionId = payload[0] as? Int else { throw WAMPMessageError.sessionIDnotFound }
		guard let details = payload[1] as? [String: Any] else { throw WAMPMessageError.detailsNotFound }
		
		self.init(sessionId: sessionId, details: details)
		
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.welcome.rawValue, self.sessionId, self.details]
	}
}

// MARK: Goodby Message

/// [GOODBYE, details|dict, reason|uri]
class GoodbyeMessage: WAMPMessage {
	
	let details: [String: Any]
	let reason: String
	
	init(details: [String: Any], reason: String) {
		self.details = details
		self.reason = reason
	}
	
	required convenience init(payload: [Any]) throws {
		
		guard let details = payload[0] as? [String: Any] else { throw WAMPMessageError.detailsNotFound }
		guard let reason = payload[1] as? String else { throw WAMPMessageError.reasonNotFound }
		
		self.init(details: details, reason: reason)
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.goodbye.rawValue, self.details, self.reason]
	}
}

// MARK: - Subscription Messages

// MARK: Subscribe Message

/// [SUBSCRIBE, requestId|number, options|dict, topic|string]
class SubscribeMessage: WAMPMessage {
	
	let requestId: Int
	let options: [String: Any]
	let topic: String
	
	init(requestId: Int, options: [String: Any], topic: String) {
		self.requestId = requestId
		self.options = options
		self.topic = topic
	}
	
	required init(payload: [Any]) {
		self.requestId = payload[0] as! Int
		self.options = payload[1] as! [String: Any]
		self.topic = payload[2] as! String
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.subscribe.rawValue, self.requestId, self.options, self.topic]
	}
}

// MARK: Subscribed Message

/// [SUBSCRIBED, requestId|number, subscription|number]
class SubscribedMessage: WAMPMessage {
	
	let requestId: Int
	let subscription: Int
	
	init(requestId: Int, subscription: Int) {
		self.requestId = requestId
		self.subscription = subscription
	}
	
	required init(payload: [Any]) {
		self.requestId = payload[0] as! Int
		self.subscription = payload[1] as! Int
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.subscribed.rawValue, self.requestId, self.subscription]
	}
}

// MARK: Unsubscribe Message

/// [UNSUBSCRIBE, requestId|number, subscription|number]
class UnsubscribeMessage: WAMPMessage {
	
	let requestId: Int
	let subscription: Int
	
	init(requestId: Int, subscription: Int) {
		self.requestId = requestId
		self.subscription = subscription
	}
	
	required init(payload: [Any]) {
		self.requestId = payload[0] as! Int
		self.subscription = payload[1] as! Int
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.unsubscribe.rawValue, self.requestId, self.subscription]
	}
}

// MARK: Unsubscribed Message

/// [UNSUBSCRIBED, requestId|number]
class UnsubscribedMessage: WAMPMessage {
	
	let requestId: Int
	
	init(requestId: Int) {
		self.requestId = requestId
	}
	
	// MARK: WAMPMessage protocol
	
	required init(payload: [Any]) {
		self.requestId = payload[0] as! Int
	}
	
	func marshal() -> [Any] {
		return [WAMPMessageType.unsubscribed.rawValue, self.requestId]
	}
}

// MARK: Event Message

/// [EVENT, subscription|number, publication|number, details|dict, args|list?, kwargs|dict?]
class EventMessage: WAMPMessage {
	
	let subscription: Int
	let publication: Int
	let details: [String: Any]
	
	let args: [Any]?
	let kwargs: [String: Any]?
	
	init(subscription: Int, publication: Int, details: [String: Any], args: [Any]?=nil, kwargs: [String: Any]?=nil) {
		self.subscription = subscription
		self.publication = publication
		self.details = details
		
		self.args = args
		self.kwargs = kwargs
	}
	
	required init(payload: [Any]) {
		self.subscription = payload[0] as! Int
		self.publication = payload[1] as! Int
		self.details = payload[2] as! [String: Any]
		self.args = payload[safe: 3] as? [Any]
		self.kwargs = payload[safe: 4] as? [String: Any]
	}
	
	func marshal() -> [Any] {
		var marshalled: [Any] = [WAMPMessageType.event.rawValue, self.subscription, self.publication, self.details]
		
		if let args = self.args {
			marshalled.append(args)
			if let kwargs = self.kwargs {
				marshalled.append(kwargs)
			}
		} else {
			if let kwargs = self.kwargs {
				marshalled.append([])
				marshalled.append(kwargs)
			}
		}
		
		return marshalled
	}
}

// MARK: - Error Messages

/// [ERROR, requestType|number, requestId|number, details|dict, error|string, args|array?, kwargs|dict?]
class ErrorMessage: WAMPMessage {
	let requestType: WAMPMessageType
	let requestId: Int
	let details: [String: Any]
	let error: String
	
	let args: [Any]?
	let kwargs: [String: Any]?
	
	init(requestType: WAMPMessageType, requestId: Int, details: [String: Any], error: String, args: [Any]?=nil, kwargs: [String: Any]?=nil) {
		self.requestType = requestType
		self.requestId = requestId
		self.details = details
		self.error = error
		self.args = args
		self.kwargs = kwargs
	}
	
	// MARK: SwampMessage protocol
	
	required init(payload: [Any]) {
		self.requestType = WAMPMessageType(rawValue: payload[0] as! Int)!
		self.requestId = payload[1] as! Int
		self.details = payload[2] as! [String: AnyObject]
		self.error = payload[3] as! String
		
		self.args = payload[safe: 4] as? [AnyObject]
		self.kwargs = payload[safe: 5] as? [String: AnyObject]
	}
	
	func marshal() -> [Any] {
		var marshalled: [Any] = [WAMPMessageType.error.rawValue, self.requestType.rawValue, self.requestId, self.details, self.error]
		if let args = self.args {
			marshalled.append(args)
			if let kwargs = self.kwargs {
				marshalled.append(kwargs)
			}
		} else {
			if let kwargs = self.kwargs {
				marshalled.append([])
				marshalled.append(kwargs)
			}
		}
		
		
		return marshalled
	}
}




