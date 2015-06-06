import types


proc newConnection*(typ: ConnectionType, id, secret, host: string): Connection =
#  var hosturl, err = url.Parse(host)
#  if not err.isNil:
#    return nil, err

  result.type = typ
  result.id = id
  result.secret = secret
  result.hosturl = host
  result.client = http.Client{}


proc authenticate(self:var Connection): error =
  # If an error is returned, zero the tokeninfo
  var err error
  var duration time.Duration

  # No need to authenticate if the previous has not yet expired
  if time.Now().Before(self.tokeninfo.expiration):
    return nil

  defer (proc() =
    if not err.isNil:
      self.tokeninfo = tokeninfo{}
  )()

  # (re)authenticate
  err = self.make_request("POST", "/oauth2/token", "grant_type=client_credentials", "", &self.tokeninfo, true)

  if not err.isNil:
    return err

  # Set the duration to expire 3 minutes early to avoid expiration during a request cycle
  duration = time.Duration(self.tokeninfo.Expires_in)*time.Second - 3*time.Minute
  self.tokeninfo.expiration = time.Now().Add(duration)

  return nil


proc auth_token(self: TokenInfo): string =
  return self.token_type & " " & self.access_token

proc make_request(self: Connection, meth, subdir: string, body: interface{}, idempotent_id: string, jsn errorable, auth_req: bool): error =
  var err error
  var result []byte
  var req *http.Request
  var resp *http.Response
  var body_reader io.Reader
  var url = "https://api"

  # use sandbox url if requested
  if pp.live == Sandbox:
    url += ".sandbox"

  url = url + ".paypal.com/" + path.Join("v1", subdir)

# Show request body
#  var s, e = json.Marshal(body)
#  if e != nil {
#    fmt.Println("marshal error", e)
#  }
#  fmt.Printf("REQUEST BODY:\n%s\n\n%s\n\n", url, s)

  switch val := body.(type) {
  case string:
    body_reader = strings.NewReader(val)
  case []byte:
    body_reader = bytes.NewReader(val)
  case nil:
    body_reader = bytes.NewReader(nil)
  default:
    result, err = json.Marshal(val)
    if not err.isNil:
      return err

    body_reader = bytes.NewReader(result)
    result = nil
  }

# TODO: Paypal docs mention a `nonce`. Research that.

  req, err = http.NewRequest(method, url, body_reader)
  if not err.isNil:
    return err

  if auth_req:
    req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
    req.SetBasicAuth(pp.id, pp.secret)
  else:
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", pp.tokeninfo.auth_token())

    # TODO: The UUID generation needs to be improved------v
    req.Header.Set("PayPal-Request-Id", idempotent_id+strconv.FormatInt(time.Now().UnixNano(), 36))

  req.Header.Set("Accept", "application/json")
  req.Header.Set("Accept-Language", "en_US")

  resp, err = pp.client.Do(req)
  if not err.isNil:
    return err

  defer resp.Body.Close()

  result, err = ioutil.ReadAll(resp.Body)

  if not err.isNil:
    return err

#/*
#  fmt.Println("RESPONSE:",string(result))
#*/

  # If there was no Body, we can return
  if result.strip.len == 0:
    return nil

  var v = reflect.ValueOf(jsn)

  if v.Kind() == reflect.Ptr:
    v = v.Elem()

  if v.Kind() == reflect.Struct:
    v = v.FieldByName("RawData")
    if v.IsValid():
      v.SetBytes(result)

  err = json.Unmarshal(result, jsn)
  #var x,y = json.Marshal(jsn)
  #fmt.Printf("=++++++++++++++++++\n%s\n%v\n",x,y)
  if not err.isNil:
    return err

  err = jsn.to_error()
  if not err.isNil:
    # Specific management for PayPal response errors
    return err

  return nil


