import base64
import duration
import httpclient
import marshal
import nuuid
import strutils
import streams
import times
import types


proc newConnection*(typ: ConnectionType, id, secret, host: string): Connection =
#  var hosturl, err = url.Parse(host)
#  if not err.isNil:
#    return nil, err

  result.type = typ
  result.id = id
  result.secret = secret
  result.hosturl = host



proc auth_token(self: TokenInfo): string =
  return self.token_type & " " & self.access_token

proc make_request*(self: Connection, typ: RType, body: any, jsn:var any) =
  var mthd = httpGet
  let dest = if self.type == ConnectionType.Sandbox: ".sandbox" else: ""
  var idem_id = ""
  var url = "https://api" & dest & ".paypal.com/v1"
  var hdrs = @["Content-Type: application/json",
              "Authorization:" & self.tokeninfo.auth_token(),
    # TODO: The UUID generation needs to be improved------v
              "PayPal-Request-Id: " & generateUUID()
              ]

  case typ
  of RType.Authenticate:
    mthd = httpPost
    url &= "/oauth2/token?grant_type=client_credentials"
    hdrs = @["Content-Type: application/x-www-form-urlencoded",
            "Authorization: Basic " & (self.id & ":" & self.secret).encode]
  of RType.PaypalPayment:
    mthd = httpPost
    url &= "/payments/payment"
    idem_id = "send_"
  else:
    discard # TODO: Handle the rest of the cases

  hdrs.add("Accept: application/json")
  hdrs.add("Accept-Language: en_US")

  var result: string

# TODO: Paypal docs mention a `nonce`. Research that.

  try:
    var strm = newStringStream()
    strm.store(body)
    strm.setPosition(0)

    let resp = request(url, mthd, hdrs.join"\c\L", strm.data, timeout=5000)

    # If there was no Body, we can return
    if resp.body.strip.len == 0:
      return

    try:
      var str = newStringStream(resp.body)
      str.load(jsn)
      # TODO: Need to handle whether or not an error was returned.
    except:
      echo "Marshal error"
      return

  except: # ValueError, OSError, HttpRequestError, OverflowError, TimeoutError, 
          # ProtocolError, Exception
    echo "FAIL"





proc authenticate*(self:var Connection) =
  # No need to authenticate if the previous has not yet expired
  if sinceEpoch() < self.tokeninfo.expiration:
    return

#  defer (proc() =
#    if not err.isNil:
#      self.tokeninfo = tokeninfo{}
#  )()

  # (re)authenticate
  try:
    self.make_request(RType.Authenticate, "", self.tokeninfo)
  except:
    self.tokeninfo = TokenInfo()

  var d: Duration = Duration 0

  # Set expiration 3 minutes early to avoid expiration during a request cycle
  let exp = sinceEpoch() + self.tokeninfo.expires_in.toDuration - 3.min
  self.tokeninfo.expiration = exp

