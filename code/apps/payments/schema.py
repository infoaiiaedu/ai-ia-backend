from pydantic import BaseModel
from typing import List
from typing import Literal, Optional, Any, Dict

class BasketItem(BaseModel):
    product_id: str
    quantity: int
    unit_price: float

class PurchaseUnit(BaseModel):
    total_amount: float
    currency: str
    basket: List[BasketItem]

class RedirectUrls(BaseModel):
    success: str
    fail: str

class CreateOrderRequest(BaseModel):
    subject_id: int
    external_order_id: str
    callback_url: str
    ttl: int
    application_type: str
    payment_method: str


class OrderStatus(BaseModel):
    key: str
    value: Optional[str]


class CallbackBody(BaseModel):
    order_id: str
    industry: Optional[str]
    # You can add more fields you need from BOG callback body,
    # for example purchase_units, buyer, payment_detail, etc.
    order_status: OrderStatus
    # Use Any or dict if structure is large/dynamic
    purchase_units: Optional[Any]
    payment_detail: Optional[Any]
    # Add other fields as needed depending on BOG docs


class BOGCallbackPayload(BaseModel):
    event: Literal["order_payment"]
    zoned_request_time: str
    body: CallbackBody