
type CaptureObject struct {
  _trans
  State            State `json:"state,omitempty"` // TODO: Limit to allowed values
  Is_final_capture bool  `json:"is_final_capture,omitempty"`
  Links            links `json:"links,omitempty"`

  RawData    []byte `json:"-"`

  *identity_error
  captures *Captures
}


func (self *Captures) Get(capt_id string) (*CaptureObject, error) {
  var capt = new(CaptureObject)
  var err = self.connection.make_request("GET",
    "payments/capture/"+capt_id,
    nil, "", capt, false)
  if err != nil {
    return nil, err
  }
  capt.captures = self
  return capt, nil
}

func (self *CaptureObject) GetParentPayment() (*PaymentObject, error) {
  return self.captures.connection.Payments.Get(self.Parent_payment)
}


func (self *CaptureObject) do_refund(ref_req interface{}) (*RefundObject, error) {
  var ref_resp = new(RefundObject)
  var err = self.captures.connection.make_request("POST",
    "payments/capture/"+self.Id+"/refund",
    ref_req, "", ref_resp, false)
  if err != nil {
    return nil, err
  }
  return ref_resp, nil
}

# the Amount must include the PayPal fee paid by the Payee
func (self *CaptureObject) Refund(amt Amount) (*RefundObject, error) {
  return self.do_refund(&RefundObject{_trans: _trans{Amount: amt}})
}

func (self *CaptureObject) FullRefund() (*RefundObject, error) {
  return self.do_refund(&RefundObject{_trans: _trans{Amount: self.Amount}})
}
