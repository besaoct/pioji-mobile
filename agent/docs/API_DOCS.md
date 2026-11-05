# Tea Trading ERP — Mobile API Integration Guide (Flutter)

| | |
|---|---|
| **Base URL** | `https://gold-sardine-283964.hostingersite.com/api/v1` |
| **Auth** | Laravel Sanctum bearer token |
| **Format** | JSON (`multipart/form-data` only for photo uploads) |
| **Last verified** | 2026-10-31 (signed in as admin; GETs and validation only) |

> ⚠️ **Server bugs (2026-10-31).** Admin login now works. Three endpoints fail with 500 and expose SQL/stack details: `GET /sales-register`, `GET /sales-register/{id}` and `GET /samples/{id}`. See [Verified responses](#verified-responses-2026-10-31).

---

## Contents

1. [Conventions](#conventions)
2. [Authentication](#authentication)
3. [Offer Lists](#1-offer-lists)
4. [Samples](#2-samples)
5. [Batches](#3-batches)
6. [Courier Register](#4-courier-register)
7. [Samples Offered Today](#5-samples-offered-today-buyer-allocation)
8. [Bid Book](#6-bid-book)
9. [Contracts](#7-contracts)
10. [Sales Register](#8-sales-register)
11. [Ex-Factory Register](#9-ex-factory-reconciliation-register)
12. [Endpoint status table](#endpoint-status-table) and [verified responses](#verified-responses-2026-10-31)
13. [Flutter client setup](#flutter-client-setup)
14. [Backend issues](#backend-issues-found-during-verification)

---

## Conventions

### Headers

Every request:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer <token>      # all routes except /auth/login
```

Always send `Accept: application/json`. Without it Laravel returns HTML redirects/error pages instead of JSON.

### Dates & numbers

- Dates: `YYYY-MM-DD` (e.g. `2026-10-17`).
- Weights are in **kg**, prices in **INR** unless a `currency` field says otherwise.
- Numeric fields accept numbers or numeric strings; send numbers.

### GET requests

**Never send a body with a GET request.** The host's firewall (Hostinger) rejects GET-with-body with `403` before Laravel sees it. Put all filters in the query string.

### Pagination

List endpoints accept `per_page` (default `20`) and `page`. Items come back under a named key next to a `pagination` object:

```json
{
  "success": true,
  "message": "…",
  "data": {
    "samples": [ { "id": 41, … } ],
    "pagination": { "current_page": 1, "last_page": 14, "per_page": 2, "total": 28, "has_more_pages": true }
  }
}
```

The key differs per endpoint (see [Verified responses](#verified-responses-2026-10-31)). `GET /sellers` is the exception: it returns Laravel's paginator (`data.data`, `data.current_page`, …). The app's `Page.parse` handles both.

### Response envelope

**Success** — `200 OK` / `201 Created`

```json
{
  "success": true,
  "message": "Resource created / retrieved successfully",
  "data": { }
}
```

**Validation error** — `422 Unprocessable Entity` *(verified)*

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password field is required."]
  }
}
```

**Bad login** — `401` *(verified)*

```json
{ "success": false, "message": "The provided credentials are incorrect." }
```

**Missing / expired token** — `401` *(verified on every protected route)*

```json
{ "message": "Unauthenticated." }
```

Note the `Unauthenticated` response has **no `success` key** — check the HTTP status code, not just `success`.

### Status codes to handle

| Code | Meaning | App action |
|---|---|---|
| 200 / 201 | OK | Parse `data` |
| 401 | No/invalid token | Clear token, go to login |
| 403 | Forbidden / firewall | Show error; check you didn't send a GET body |
| 404 | Not found | Show "not found" |
| 422 | Validation | Show `errors[field][0]` under each field |
| 5xx | Server error | Generic error + retry |

---

## Authentication

### `POST /auth/login`

Exchanges email + password for a Sanctum token.

**Body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `email` | string | ✅ | |
| `password` | string | ✅ | |
| `device_name` | string | ✅ | Any label, e.g. `Flutter_Pixel_8` |

```json
{
  "email": "admin@example.com",
  "password": "********",
  "device_name": "Flutter_Pixel_8"
}
```

**Success** — `200` *(verified 2026-10-31)*

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": 6, "name": "Super Admin", "email": "admin@example.com", "phone": null, "role": "supervisor", "role_text": "Supervisor", "department": "Administration", "permissions": ["samples.view", "…"], "status": "…", "status_text": "…", "last_login_at": "…" },
    "token": "<sanctum token>",
    "token_type": "Bearer",
    "abilities": ["…"]
  }
}
```

Store `data.token` securely (`flutter_secure_storage`) and send it as `Authorization: Bearer <token>`. `GET /auth/me` returns the same `data.user`.

**Errors (verified)**
- Empty body → `422` with `email`, `password`, `device_name` required.
- Wrong credentials → `401 "The provided credentials are incorrect."`

---

## 1. Offer Lists

### 1.1 `GET /offer-lists` — list

| Query | Type | Notes |
|---|---|---|
| `search` | string | Garden, Grade, AWR No, or Key |
| `garden_id` | int | |
| `grade` | string | e.g. `BOP`, `BP` |
| `type` | string | e.g. `Tea` |
| `date_from` / `date_to` | date | |
| `per_page` / `page` | int | default 20 |

### 1.2 `POST /offer-lists` — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `date` | date | ✅ | |
| `garden_id` | int | ✅ | |
| `inv_no` | string | ✅ | |
| `inv_prefix` (alias `inv_pretx`) | string | | e.g. `IVP` |
| `garden_name` | string | | |
| `grade` | string | | `BOP`, `BP`, `OF`… |
| `pkgs` | number | | packages |
| `nett` | number | | kg per package |
| `ttl_kgs` | number | | **2-of-3 rule:** send any two of `pkgs`/`nett`/`ttl_kgs`, the third is computed |
| `gross_weight` | number | | |
| `d_o_packing` | date | | date of packing |
| `type` | string | | `Tea` |
| `price` | number | | |
| `currency` | string | | `INR` |
| `prompt_days` | int | | |
| `party_1`, `party_2` | string | | |
| `duplicate_action` | string | | `override` \| `reoffer` \| `reject` — what to do if the invoice already exists |

```json
{
  "date": "2026-10-17",
  "garden_id": 1,
  "garden_name": "Assam Valley",
  "grade": "BOP",
  "inv_prefix": "IVP",
  "inv_no": "1045",
  "pkgs": 20,
  "nett": 35.0,
  "ttl_kgs": 700.0,
  "gross_weight": 720.0,
  "d_o_packing": "2026-10-10",
  "type": "Tea",
  "price": 280.00,
  "currency": "INR",
  "prompt_days": 14,
  "party_1": "Tata Tea",
  "party_2": "Wagh Bakri",
  "duplicate_action": "override"
}
```

---

## 2. Samples

### 2.1 `GET /samples` — list

| Query | Type | Notes |
|---|---|---|
| `search` | string | |
| `status` | string | `received` \| `pending_evaluation` \| `evaluated` \| `assigned_to_buyers` \| `approved` |
| `arrival_date` | date | |
| `per_page` / `page` | int | |

### 2.2 `POST /samples` — create

All fields optional.

| Field | Type | Notes |
|---|---|---|
| `arrival_date` | date | defaults to today |
| `garden_id` | int | |
| `grade` | string | |
| `invoice_prefix` | string | |
| `inv_no` | string | |
| `packages` (alias `pkgs`) | int | |
| `weight` (alias `nett`) | number | kg per package |
| `total_kgs` | number | 2-of-3 rule with packages/weight |
| `sample_type` | string | `Original`, `Standard`, … |
| `status` | string | see list statuses |
| `remarks` | string | |
| `is_duplicate` | bool | `true` to force-save when the invoice already exists |

```json
{
  "arrival_date": "2026-10-17",
  "garden_id": 1,
  "grade": "BOP",
  "invoice_prefix": "SMP",
  "inv_no": "2048",
  "packages": 15,
  "weight": 40.0,
  "total_kgs": 600.0,
  "sample_type": "Original",
  "status": "received",
  "remarks": "Clean liquor sample"
}
```

---

## 3. Batches

### 3.1 `GET /batches` — list

Query: `status` (`open` \| `closed`), `date`, `search`, `per_page`, `page`.

### 3.2 `POST /batches` — create

| Field | Type | Notes |
|---|---|---|
| `batch_name` | string | auto-generated if empty |
| `batch_date` | date | defaults to today |
| `status` | string | `open` (default) \| `closed` |
| `notes` | string | |
| `sample_ids` | int[] | **max 48** per batch |

```json
{
  "batch_name": "Tasting Batch - Morning Session",
  "batch_date": "2026-10-17",
  "status": "open",
  "notes": "Testing premium BOP lots",
  "sample_ids": [12, 14, 18, 22]
}
```

### 3.3 `POST /batches/create-for-date` — auto-batch

Groups every unbatched sample for the date into batches of up to 48.

```json
{ "date": "2026-10-17" }
```

### 3.4 `GET /batches/unbatched-samples?date=YYYY-MM-DD`

Samples for that date not yet in any batch. Use this to build the sample picker for 3.2.

---

## 4. Courier Register

### 4.1 `GET /courier-entries` — list

| Query | Type | Notes |
|---|---|---|
| `search` | string | Entry No, Tracking No, Courier Name, Buyer Name |
| `buyer_id` | int | |
| `courier_service_id` | int | |
| `pickup_day` | string | `Monday` … `Sunday` |
| `date` | date | |
| `per_page` / `page` | int | |

### 4.2 `POST /courier-entries` — create

Send `application/json`, or `multipart/form-data` when attaching `photo`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `tracking_number` | string | ✅ | **letters and digits only** — no spaces, dashes or symbols |
| `destination_type` | string | | `buyer` (default) \| `custom` |
| `buyer_id` | int | ✅ if `buyer` | |
| `courier_address_id` | int | ✅ if `custom` | from 4.4 |
| `courier_service_id` | int | | from 4.4 |
| `courier_name` | string | | manual name if no service id |
| `destination_address` | string | | prefill from 4.3 |
| `pickup_date` | date | | |
| `pickup_day` | string | | |
| `is_auc` / `is_pvt` | bool | | auction / private |
| `weight` | number | | kg |
| `description` | string | | |
| `photo` | file | | jpg/png/webp, max 25 MB |
| `posting_list_ids` | int[] | | multipart: send as `posting_list_ids[]` |

```json
{
  "destination_type": "buyer",
  "buyer_id": 1,
  "courier_service_id": 2,
  "courier_name": "Blue Dart Express",
  "tracking_number": "BD98273491",
  "destination_address": "Plot 12, Tea Park, Kolkata, WB - 700001",
  "pickup_date": "2026-10-17",
  "pickup_day": "Saturday",
  "is_auc": false,
  "is_pvt": true,
  "weight": 2.5,
  "description": "5 Sample packets for evaluation",
  "posting_list_ids": [101, 102]
}
```

Tracking-number validation error:

```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "tracking_number": ["The Barcode / Tracking ID may only contain letters and numbers without special characters."]
  }
}
```

In multipart requests send booleans as `1`/`0`; PHP does not read `"true"`/`"false"` strings as booleans.

### 4.3 `GET /courier-entries/buyer-address/{buyerId}`

Returns the buyer's billing address, POC address, phone and WhatsApp numbers. Call it when the user picks a buyer, to prefill `destination_address`.

### 4.4 `GET /courier-entries/services`

Courier services and saved custom addresses, for the dropdowns in 4.2.

---

## 5. Samples Offered Today (Buyer Allocation)

### 5.1 `GET /samples-offered-today?date=YYYY-MM-DD`

`date` defaults to today. Returns `offer_lists`, `samples` and `available_buyers`, with counts.

### 5.2 `POST /samples-offered-today/allocate-buyers`

| Field | Type | Required | Notes |
|---|---|---|---|
| `item_type` | string | ✅ | `offer_list` \| `sample` |
| `item_id` | int | ✅ | |
| `buyer_ids` | int[] | ✅ | |

```json
{ "item_type": "offer_list", "item_id": 2, "buyer_ids": [1, 4, 7] }
```

### 5.3 `POST /samples-offered-today/bulk-allocate-buyers`

```json
{
  "items": [
    { "type": "offer_list", "id": 2 },
    { "type": "sample", "id": 5 }
  ],
  "buyer_ids": [1, 3]
}
```

---

## 6. Bid Book

### 6.1 `GET /bid-book` — list

| Query | Type | Notes |
|---|---|---|
| `tab` | string | `all` \| `open` \| `parked` \| `held` \| `awaiting_allocation` |
| `search` | string | Invoice, Garden, Grade, Buyer, Negotiator |
| `garden_id` | int | |
| `grade` | string | |
| `status` | string | `open` \| `parked` \| `OK-BID HOLD` \| `closed` |
| `per_page` / `page` | int | |

`OK-BID HOLD` contains a space — URL-encode it (`OK-BID%20HOLD`). Dart's `Uri`/Dio do this automatically.

### 6.2 `POST /bid-book` — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `garden_name` | string | ✅ | garden / mark |
| `grade` | string | ✅ | |
| `invoice_number` | string | ✅ | |
| `packages` | int | ✅ | |
| `net_weight` | number | ✅ | kg |
| `status` | string | ✅ | `open` \| `parked` \| `OK-BID HOLD` \| `closed` |
| `seller_incoming_price` | number | | |
| `max_bid` | number | | |
| `negotiated_price` | number | | |
| `pencil_price` | number | | |
| `buyer_id` | int | | omit → lot is unallocated |
| `negotiator_id` | int | | user id |
| `remarks` | string | | |

```json
{
  "garden_name": "Assam Valley",
  "grade": "BP",
  "invoice_number": "INV-BB-891",
  "packages": 30,
  "net_weight": 1050.0,
  "seller_incoming_price": 270.00,
  "max_bid": 290.00,
  "negotiated_price": 285.00,
  "pencil_price": 288.00,
  "status": "open",
  "buyer_id": 1,
  "negotiator_id": 2,
  "remarks": "High quality orthodox lot"
}
```

### 6.3 `PUT /bid-book/{id}` — update

Same fields as create. Send the fields you want to change.

---

## 7. Contracts

### 7.1 `GET /contracts` — list

| Query | Type | Notes |
|---|---|---|
| `search` | string | title, number, seller |
| `status` | string | `draft` \| `active` \| `expired` \| `cancelled` |
| `seller_id` / `buyer_id` | int | |
| `date_from` | date | by effective date |
| `date_to` | date | by expiry date |
| `per_page` / `page` | int | |

### 7.2 `POST /contracts` — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `seller_id` | int | ✅ | |
| `contract_title` | string | ✅ | |
| `effective_date` | date | ✅ | |
| `expiry_date` | date | ✅ | must be ≥ `effective_date` |
| `buyer_id` | int | | |
| `contract_number` | string | | auto-generated if omitted (e.g. `CON2026100001`) |
| `prompt_days` | int | | |
| `discount` | number | | |
| `status` | string | | `draft` \| `active` \| `expired` \| `cancelled` |
| `terms_and_conditions` | string | | |
| `contract_items` | array | | see below |

`contract_items[]`: `tea_grade` (string), `price_per_kg` (number), `quantity` (number, kg), `currency` (string).

```json
{
  "seller_id": 1,
  "buyer_id": 1,
  "contract_title": "Tea Supply Contract 2026 - Tata Tea",
  "effective_date": "2026-10-17",
  "expiry_date": "2026-11-17",
  "prompt_days": 14,
  "discount": 0.0,
  "status": "draft",
  "terms_and_conditions": "Payment within prompt days",
  "contract_items": [
    { "tea_grade": "BOP", "price_per_kg": 320.00, "quantity": 5000.0, "currency": "INR" },
    { "tea_grade": "BP",  "price_per_kg": 290.00, "quantity": 3000.0, "currency": "INR" }
  ]
}
```

---

## 8. Sales Register

### 8.1 `GET /sales-register` — list

| Query | Type | Notes |
|---|---|---|
| `search` | string | Mark, Invoice, Buyer, Entry ID |
| `buyer_id` | int | |
| `tea_grade` | string | |
| `start_date` / `end_date` | date | deal / entry date |
| `status` | string | `pending` \| `confirmed` \| `dispatched` \| `delivered` |
| `per_page` / `page` | int | |

### 8.2 `POST /sales-register` — create

| Field | Type | Required | Notes |
|---|---|---|---|
| `buyer_id` | int | ✅ | |
| `tea_grade` | string | ✅ | |
| `rate_per_kg` | number | ✅ | INR |
| `mark` | string | | garden mark |
| `invoice_prefix` / `invoice_no` | string | | |
| `pkgs` | int | | |
| `quantity_kg` | number | | |
| `deal_date` | date | | |
| `cn_number` / `cn_date` | string / date | | consignment / bilty |
| `transport` | string | | transporter |
| `discount` | number | | |
| `remarks` | string | | |

```json
{
  "buyer_id": 1,
  "tea_grade": "BOP",
  "rate_per_kg": 310.00,
  "pkgs": 25,
  "quantity_kg": 875.0,
  "mark": "Assam Valley Mark",
  "invoice_prefix": "IVP",
  "invoice_no": "9812",
  "deal_date": "2026-10-17",
  "cn_number": "CN-44129",
  "cn_date": "2026-10-17",
  "transport": "V-Trans Logistics",
  "discount": 0.0,
  "remarks": "Dispatched directly from factory"
}
```

---

## 9. Ex-Factory Reconciliation Register

### 9.1 `GET /ex-factory` — list with status metrics

| Query | Type | Notes |
|---|---|---|
| `search` | string | Bill No, Supplier, Mark, Invoice No, Transporter |
| `register_status` | string | `matched` \| `price_mismatch` \| `qty_mismatch` \| `unregistered` |
| `supplier_id` | int | |
| `start_date` / `end_date` | date | |
| `per_page` / `page` | int | |

### 9.2 `GET /ex-factory/export` — CSV

Same filters as 9.1. Returns a streamed **`text/csv`** file (`ex_factory_bills_YYYY-MM-DD.csv`, 40 columns), **not JSON**. In Dio, use `responseType: ResponseType.bytes` (or `dio.download`) and save to a file.

### 9.3 `POST /ex-factory` — create (auto-reconciles with Sales Register)

| Field | Type | Required | Notes |
|---|---|---|---|
| `bill_date` | date | ✅ | |
| `mark` | string | ✅ | |
| `invoice_no` | string | ✅ | |
| `pkgs` | int | ✅ | |
| `nett` | number | ✅ | total kg |
| `taxable_value` | number | ✅ | INR |
| `gst_type` | string | ✅ | `igst` \| `cgst_sgst` |
| `igst_amount` | number | | when `igst` |
| `cgst_amount` / `sgst_amount` | number | | when `cgst_sgst` |
| `invoice_prefix` | string | | |
| `supplier_id` | int | | |
| `total_bill_value` | number | | incl. tax |
| `cn_number` / `cn_date` | string / date | | |
| `transport` | string | | |
| `credit_days` | int | | |

```json
{
  "bill_date": "2026-10-17",
  "mark": "Assam Valley Mark",
  "invoice_no": "9812",
  "invoice_prefix": "IVP",
  "supplier_id": 1,
  "pkgs": 25,
  "nett": 875.0,
  "taxable_value": 271250.00,
  "gst_type": "igst",
  "igst_amount": 13562.50,
  "total_bill_value": 284812.50,
  "cn_number": "CN-44129",
  "cn_date": "2026-10-17",
  "transport": "V-Trans Logistics",
  "credit_days": 15
}
```

The bill is matched to a Sales Register entry by mark + invoice. Its `register_status` becomes `matched`, `price_mismatch`, `qty_mismatch` or `unregistered`.

---

## Endpoint status table

Routes checked on 2026-10-29/30; responses checked signed in on 2026-10-31. ✅ = real response seen and parsed by the app. "422 only" = sent with an empty body to avoid creating data, so only validation was seen.

| # | Method | Path | Route exists | Auth enforced | Response shape verified |
|---|---|---|---|---|---|
| — | POST | `/auth/login` | ✅ | n/a | ✅ errors only (422/401) |
| 1.1 | GET | `/offer-lists` | ✅ | ✅ | ✅ |
| 1.2 | POST | `/offer-lists` | ✅ | ✅ | 422 only |
| 2.1 | GET | `/samples` | ✅ | ✅ | ✅ |
| 2.2 | POST | `/samples` | ✅ | ✅ | not tested (all fields optional, would create data) |
| 3.1 | GET | `/batches` | ✅ | ✅ | ✅ |
| 3.2 | POST | `/batches` | ✅ | ✅ | not tested (all fields optional, would create data) |
| 3.3 | POST | `/batches/create-for-date` | ✅ | ✅ | not tested (all fields optional, would create data) |
| 3.4 | GET | `/batches/unbatched-samples` | ✅ | ✅ | ✅ |
| 4.1 | GET | `/courier-entries` | ✅ | ✅ | ✅ |
| 4.2 | POST | `/courier-entries` | ✅ | ✅ | 422 only |
| 4.3 | GET | `/courier-entries/buyer-address/{id}` | ✅ | ✅ | ✅ |
| 4.4 | GET | `/courier-entries/services` | ✅ | ✅ | ✅ |
| 5.1 | GET | `/samples-offered-today` | ✅ | ✅ | ✅ |
| 5.2 | POST | `/samples-offered-today/allocate-buyers` | ✅ | ✅ | 422 only |
| 5.3 | POST | `/samples-offered-today/bulk-allocate-buyers` | ✅ | ✅ | 422 only |
| 6.1 | GET | `/bid-book` | ✅ | ✅ | ✅ |
| 6.2 | POST | `/bid-book` | ✅ | ✅ | 422 only |
| 6.3 | PUT | `/bid-book/{id}` | ✅ | ✅ | not tested (would change data) |
| 7.1 | GET | `/contracts` | ✅ | ✅ | ✅ |
| 7.2 | POST | `/contracts` | ✅ | ✅ | 422 only |
| 8.1 | GET | `/sales-register` | ✅ | ✅ | ❌ 500 (server bug) |
| 8.2 | POST | `/sales-register` | ✅ | ✅ | 422 only |
| 9.1 | GET | `/ex-factory` | ✅ | ✅ | ✅ |
| 9.2 | GET | `/ex-factory/export` | ✅ | ✅ | ✅ |
| 9.3 | POST | `/ex-factory` | ✅ | ✅ | 422 only |

## Verified responses (2026-10-31)

Signed in as admin. Only GET requests, plus create requests with an empty body (all returned 422; nothing was created). Not tested: creating samples or batches, auto-batch, allocation with real data, every `PUT` and `DELETE`, logout.

### List endpoints

| Endpoint | Status | Items key in `data` | Notable item fields |
|---|---|---|---|
| `GET /offer-lists` | ✅ 200 | `offer_lists` | `garden_name`, `garden` (object), `grade` (text), `inv_pretx`, `inv_no`, `pkgs`, `nett`, `ttl_kgs`, `price`, `date`, `buyer` |
| `GET /samples` | ✅ 200 | `samples` | `garden_name`, `grade` **object** `{code, tea_type}`, `invoice_prefix` **object** `{code, invoice_type}`, `inv_no`, `pkgs`, `nett`, `total_kgs`, `status`, `batch_id` **text** (e.g. `BATCH20261030001-06`) |
| `GET /batches` | ✅ 200 | `batches` | `batch_number`, `batch_date`, `total_samples`, `max_samples`, `samples_count`, `status`, `remarks` |
| `GET /courier-entries` | ✅ 200 | `entries` | `entry_number`, `tracking_number`, `courier_name`, `buyer_name`, `buyer` (object), `courier_service` (object, `company_name`), `pickup_date`, `pickup_day`, `is_auc`, `is_pvt`, `weight` |
| `GET /bid-book` | ✅ 200 | `lots` | `garden_name`, `grade`, `invoice_number`, `packages`, `net_weight`, prices, `status` (`OK-BID HOLD` etc.), `holder_status`, `buyer` / `negotiator` (objects or null) |
| `GET /contracts` | ✅ 200 | `contracts` | `contract_number`, `contract_title`, dates, `status`, `seller` (object, `seller_name`), `contract_items[]` (`tea_grade`, `price_per_kg`, `quantity`, `currency`) |
| `GET /ex-factory` | ✅ 200 | `bills` (+ `metrics`) | `metrics`: `total_bills`, `total_pkgs`, `total_kgs`, `total_taxable`, `total_bill_value`, `total_payable`, `total_paid`, `matched_count`, `mismatch_count`, `unregistered_count` |
| `GET /sales-register` | ❌ **500** | — | See server bugs |
| `GET /gardens` | ✅ 200 | `gardens` (2,183 total) | `garden_name`, `city`, aliases. Use `search` + paging, never load all |
| `GET /buyers` | ✅ 200 | `buyers` | `buyer_name`, `buyer_type`, `contact_person`, `email`, `phone` |
| `GET /sellers` | ✅ 200 | Laravel paginator: `data.data` | `seller_name`, `tea_estate_name`, `city` |
| `GET /grades` | ✅ 200 | `grades` (219 total) | `grade_code`, `grade_name`, `category` |
| `GET /posting-lists` | ✅ 200 | `posting_lists` (+ `statuses`) | `name`, `list_number`, `list_date`, `status`, `items_count` |
| `GET /negotiators` | ✅ 200 | `data` is a plain list | `id`, `name`, `email`, `role`, `department` |

Filters verified: `search`, `status`, `tab` (bid book), `date_from` / `date_to`, `register_status`.

### Other endpoints

| Endpoint | Status | Shape |
|---|---|---|
| `GET /auth/me` | ✅ 200 | `data.user` (same as login) |
| `GET /batches/unbatched-samples?date=` | ✅ 200 | `data` is a list of samples |
| `GET /courier-entries/services` | ✅ 200 | `data.courier_services[]` (`company_name`), `data.courier_addresses[]` (`address_title`, `address_line_1`, `city`) |
| `GET /courier-entries/buyer-address/{id}` | ✅ 200 | `data`: `buyer_id`, `name`, `address`, `phone`, `whatsapp` |
| `GET /samples-offered-today?date=` | ✅ 200 | `data`: `date`, `total_offer_lists`, `total_samples`, `offer_lists[]`, `samples[]` (each with `assigned_buyers[]` of buyer objects), `available_buyers[]` (`buyer_name`) |
| `GET /ex-factory/export` | ✅ 200 | `text/csv` file |
| `GET /offer-lists/{id}`, `/batches/{id}`, `/courier-entries/{id}`, `/bid-book/{id}`, `/contracts/{id}` | ✅ 200 | `data` is the record |
| `GET /ex-factory/{id}` | ✅ 404 | No bills exist yet, so not fully verified |
| `GET /samples/{id}` | ❌ **500** | See server bugs |
| `GET /sales-register/{id}` | ❌ **500** | See server bugs |

### Required fields (from 422 responses)

| Endpoint | Required |
|---|---|
| `POST /offer-lists` | `date`, `garden_id`, `inv_no` |
| `POST /courier-entries` | `tracking_number`, `buyer_id` (or custom address), `courier_name` when no `courier_service_id` |
| `POST /bid-book` | `garden_name`, `grade`, `invoice_number`, `packages`, `net_weight`, `status` |
| `POST /contracts`, `/sales-register`, `/ex-factory`, `/samples-offered-today/*` | As documented above (all returned 422 for an empty body) |

### Server bugs

| # | Endpoint | Error | Note |
|---|---|---|---|
| 1 | `GET /sales-register` | 500 `Array to string conversion` while **inserting** into `sales_registers` ("Auto-created on sample dispatch") | A GET must not write. The insert fails, so the whole list is unusable. The message also leaks the database name, host and full SQL |
| 2 | `GET /sales-register/{id}` | 500 `Call to undefined relationship [garden] on model [App\Models\SalesRegister]` | Remove `garden` from the eager loads or add the relation |
| 3 | `GET /samples/{id}` | 500 `Call to undefined method App\Services\SampleService::getSampleDetailsForMobile()` | Missing service method |
| 4 | Errors in general | Exception text returned to clients | Set `APP_DEBUG=false`; return a generic message |
| 5 | `GET /samples?arrival_date=…` | Filter ignored: always returns every sample (verified 2026-11-05; `date`, `date_from`/`date_to` also ignored) | Apply the filter server-side. Until then the app's arrival filter and a "samples today" count can't work |

**Dates** are sent in UTC, e.g. `2026-10-29T18:30:00.000000Z` means 30 Oct 2026 in India. Convert to local time before showing a date (the app does).

### Still missing

| Method | Path | Today |
|---|---|---|
| PUT | `/{id}` on offer lists, batches, courier, contracts, sales, ex-factory | 405 |
| DELETE | `/{id}` on every module except samples | 405 |
| GET | `/dashboard/summary` (optional) | HTML 404 page, status 200 |
| — | Unknown `/api/v1/*` paths | HTML 404 page with status 200 instead of JSON 404 |

---

## Flutter client setup

Suggested packages: `dio`, `flutter_secure_storage`.

### API client

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const baseUrl = 'https://gold-sardine-283964.hostingersite.com/api/v1';

  final _storage = const FlutterSecureStorage();
  late final Dio dio;

  /// Called when the server rejects the token; navigate to login.
  void Function()? onUnauthorized;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          await _storage.delete(key: 'token');
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  Future<void> login(String email, String password, String deviceName) async {
    final res = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_name': deviceName,
    });
    await _storage.write(key: 'token', value: res.data['token'] as String);
  }

  Future<void> logout() => _storage.delete(key: 'token');
}
```

> The exact location of `token` in the login response (`res.data['token']` vs `res.data['data']['token']`) is unverified. Confirm it once admin login works.

### Reading validation errors

```dart
Map<String, String> fieldErrors(DioException e) {
  final errors = e.response?.data is Map ? e.response!.data['errors'] : null;
  if (errors is! Map) return {};
  return errors.map((k, v) => MapEntry(k as String, (v as List).first as String));
}
```

### List with filters (query string, no body)

```dart
final res = await api.dio.get('/samples', queryParameters: {
  'status': 'received',
  'arrival_date': '2026-10-17',
  'per_page': 20,
  'page': 1,
});
```

### Courier entry with photo (multipart)

```dart
final form = FormData.fromMap({
  'destination_type': 'buyer',
  'buyer_id': 1,
  'tracking_number': 'BD98273491',
  'pickup_date': '2026-10-17',
  'is_auc': 0,
  'is_pvt': 1,
  'weight': 2.5,
  'posting_list_ids[]': [101, 102],
  'photo': await MultipartFile.fromFile(photoPath, filename: 'parcel.jpg'),
});
await api.dio.post('/courier-entries', data: form);
```

### Ex-factory CSV download

```dart
await api.dio.download(
  '/ex-factory/export',
  '${dir.path}/ex_factory_bills.csv',
  queryParameters: {'register_status': 'price_mismatch'},
);
```

### Client-side checks that mirror the server

- `tracking_number`: `RegExp(r'^[A-Za-z0-9]+$')`
- `expiry_date >= effective_date` on contracts
- `sample_ids.length <= 48` on batches
- 2-of-3 rule: when the user enters two of packages / nett / total, compute the third (`total = pkgs × nett`).

---

## Backend issues found during verification

| # | Severity | Issue | Fix |
|---|---|---|---|
| 1 | ~~Blocker~~ Fixed 2026-10-31 | `POST /auth/login` rejected admin credentials that work on `/admin/login`. The API checks the `users` table/guard, but admins are a separate guard. | Let the API login authenticate admins: check the admin model, or make `Admin` use `HasApiTokens` and issue the token from it. Make sure `auth:sanctum` resolves admin tokens too. |
| 2 | High | `APP_DEBUG` is on in production. Errors return the exception class and trace (e.g. calling `POST /api/v1/login`). | Set `APP_DEBUG=false` in `.env`, then run `php artisan config:cache`. |
| 3 | Medium | Unknown `/api/v1/*` paths return **HTTP 200 with an HTML 404 page** instead of a JSON 404. The app sees "success" and then fails parsing. | Add an API fallback: `Route::fallback(fn () => response()->json(['success' => false, 'message' => 'Not found'], 404));` in `routes/api.php`. Exclude `api/*` from the web catch-all route. |
| 4 | Low | GET requests that carry a body get `403` from the hosting firewall. | Client rule: no body on GET (already covered above). |
| 5 | Low | The `401 Unauthenticated` body has no `success` field, unlike every other response. | Optional: render `AuthenticationException` as `{ "success": false, "message": "Unauthenticated." }`. |
