# **Smart Contract Specification Document: Abstracted Roles for Order Validation and Buy/Sell Transactions**

## **Project Overview**
This blockchain-based e-commerce platform securely records buy, sell, and order validation transactions. Key roles in the smart contract include:
- **SubmitterForValidation**: Manages product listings.
- **Validator**: Validates orders post-purchase.
- **Seller**: Handles order and delivery management.
- **Delivery Person**: Tracks delivery progress.
- **Buyer**: Purchases products.

These roles are assigned and managed by the backend, abstracting complexity for the end user. Products become immediately available upon listing, and Validators only engage when an order is created to ensure product specifications match the listing before finalization.

## **Smart Contract Requirements**

### **1. Contract Roles and Permissions**
- **SubmitterForValidation**: Manages product listings, with products immediately available in the marketplace.
- **Validator**: Engages when an order is created, confirming that ordered products match Seller specifications.
- **Seller**: Manages listings, assigns Delivery Persons, and updates order status.
- **Delivery Person**: Tracks and updates delivery progress.
- **Buyer**: Purchases products and confirms order completion.
- **Admin**: Oversees validator approvals and role assignments.

## **2. Functional Components**

### **A. Product Listing and Marketplace Availability**
- **Product Structure**: Each product has a unique identifier, name, description, price, and associated seller’s address.
- **Immediate Marketplace Listing**: Products listed by **SubmitterForValidation** are available in the marketplace without initial validation.

### **B. Order Creation and Validation**
- **Order Creation**: Buyers place an order, prompting notifications to the Seller and available Validators.
- **Order Validation**: Validators confirm that order details match the Seller’s listing, updating the order status to “Validated” or “Rejected.”
- **Assignment of Delivery**: Once validated, Sellers assign a Delivery Person.

### **C. Delivery Tracking**
- **Order Status Updates**:
  - **Delivery In Progress**: Updated when the Delivery Person begins delivery.
  - **Delivery Completed**: Updated by the Delivery Person upon completion.
  - **Order Finalization**: The Seller marks the order as “Complete,” and the Buyer confirms, marking it as “Finalized.”

## **3. Smart Contract Functions**

### **A. SubmitterForValidation Functions**
- `listProduct(productId, name, description, price)`: Lists a product on the marketplace, making it immediately available for purchase.

### **B. Validator Functions**
- `validateOrder(orderId)`: Confirms order details, updating status to “Validated” or “Rejected.”

### **C. Seller Functions**
- `assignDelivery(orderId, deliveryPersonAddress)`: Assigns a Delivery Person post-validation.
- `completeOrder(orderId)`: Marks the order as “Complete.”

### **D. Delivery Person Functions**
- `updateDeliveryStatus(orderId, status)`: Updates delivery status to “In Progress” or “Delivery Completed.”

### **E. Buyer Functions (Managed by Backend)**
- `confirmOrderCompletion(orderId)`: Confirms and finalizes the order.

### **F. Admin Functions**
- `approveValidator(validatorAddress)`: Approves validators for role activation.
- `assignRole(userAddress, role)`: Assigns roles for secure, backend-managed operations.

## **4. Data Structures**

### **Product Structure**
```solidity
struct Product {
    uint productId;
    string name;
    string description;
    uint price;
    address seller;
}
```

### **Order Structure**
```solidity
struct Order {
    uint orderId;
    uint productId;
    address buyer;
    address seller;
    address validator;
    address deliveryPerson;
    bool isValidated;
    OrderStatus status; // Enum: Pending, Validated, Delivery In Progress, Delivery Completed, Finalized
}
```

## **5. Smart Contract Workflow**

1. **Product Listing**
   - **SubmitterForValidation** lists products, making them immediately available in the marketplace.

2. **Order Creation**
   - Buyers place an order, notifying the Seller and Validators.

3. **Order Validation**
   - Validators check if order details match the Seller’s listing and update the order status accordingly.

4. **Assign Delivery**
   - Upon validation, the Seller assigns a Delivery Person.

5. **Delivery Tracking and Completion**
   - The Delivery Person marks delivery as “Completed” upon completion.
   - The Seller and Buyer confirm order completion, marking it as “Finalized.”

## **6. Security Considerations**

- **Role-Based Access Control**: Authorized addresses, managed by the backend, perform specific actions.
- **Validator Approval**: Only verified Validators, approved by Admins, validate orders.
- **Data Immutability**: Ensures order, validation, and delivery logs are immutable.
- **Reentrancy Guard**: Protects functions involving funds if escrow is considered in the future.

## **7. Future Considerations**

- **Reputation System**: Incentivize reliable Validators, Sellers, and Delivery Persons.
- **Scalable Notification System**: Integrate off-chain notifications for Validators to track new orders needing validation.