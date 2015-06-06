
#/*
#import "time"
#
#
#// TODO: It could be that not all this information will need to be stored in a database.
#//		 It may prove beneficial to only store Communication data, and just a minimal
#//			amount, and rely on PayPal for fetching the data when needed.
#
#type TransactionLog struct {
#	TransactionID string // UUID for this transaction
#	PayPalTransactionID string
#	ParentPayPalTransactionID string
#	Type int // TODO: Const enum... Payment, Refund, Authorization, etc.
#	State string // TODO: Const enum as defined... Created, Approved, Canceled, etc.
#}
#
#type CommunicationLog struct {
#	TransactionID string
#	CommunicationID string // UUID for this communication. It's the same as its Transaction UUID, but with the type prepended
#	Type int // TODO: This should be a const enum type. Request, Response, Internal
#	RawData string
#	TimeStamp time.Time
#}
#
#
#*/
