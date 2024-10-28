# **Smart Contract Specification Document: Abstracted Roles for Buy/Sell and Product Validation Transactions**

## **Project Overview**
This blockchain-based e-commerce platform records secure and immutable buy, sell, and product validation transactions. Key roles in the smart contract include a **SubmitterForValidation** for product listings, a **Validator** for product approval, and a **Buyer** for purchase transactions. The backend assigns and manages these roles, abstracting complexity for the end user. Validators interact directly with the blockchain and receive real-time updates on products pending validation.

---

## **Smart Contract Requirements**

### **1. Contract Roles and Permissions**
   - **SubmitterForValidation**: A backend-assigned role for managing product listing and buying on behalf of users.
   - **Validator**: A blockchain-registered role where verified users (validated by an admin) directly interact with the smart contract to approve or reject product listings. Validators receive notifications (via backend integration) for any new listings awaiting validation.
   - **Buyer**: A backend-assigned role that allows registered users to purchase validated products. The backend interface handles purchase transactions and escrow confirmations.
   - **Admin**: Oversees validator approvals and manages role assignments.

---

## **2. Functional Components**

### **A. Product Listing and Validation**
   - **Product Structure**: Each product has a unique identifier, name, description, price, and associated seller’s address.
   - **Listing by SubmitterForValidation**: Products are listed by the **SubmitterForValidation** role, managed by the backend, and marked as “Pending Validation.”
   - **Direct Validation**: Validators interact directly with the contract to approve or reject products. Validators receive notifications (via backend integration) for any new listings awaiting validation.

### **B. Buy and Sell Transactions**
   - **Purchase Process**: Buyers interact with the backend to purchase validated products, creating a transaction record on the blockchain.
   - **Escrow Mechanism** (if applicable): Payments are held in escrow until a purchase transaction is confirmed by the buyer, ensuring secure transactions.

---

## **3. Smart Contract Functions**

### **A. SubmitterForValidation Functions**
   - **`listProduct(productId, name, description, price)`**: Allows the **SubmitterForValidation** role to add a product to the marketplace. Products are set to “Pending Validation.”
   - **`confirmSale(orderId)`**: Confirms the sale upon purchase completion by the buyer (optional if escrow is used).

### **B. Validator Functions**
   - **`registerValidator(validatorAddress)`**: Validators create profiles on the blockchain, pending verification by an admin.
   - **`validateProduct(productId)`**: Validators directly approve products after review, marking them as available for purchase.
   - **`rejectProduct(productId)`**: Rejects a product if it does not meet platform standards, recorded on the blockchain.

### **C. Buyer Functions (Managed by Backend)**
   - **`purchaseProduct(productId)`**: Buyers purchase a product via the backend, which interacts with the contract to log the transaction and manage escrow.
   - **`confirmReceipt(orderId)`**: Confirms receipt of a product, releasing funds to the seller if escrow is used.

### **D. Admin Functions**
   - **`approveValidator(validatorAddress)`**: Verifies and activates a validator’s profile after registration.
   - **`assignRole(userAddress, role)`**: Assigns roles (SubmitterForValidation, Buyer) for secure backend-managed operations.

---

## **4. Data Structures**

### **Product Structure**
```solidity
struct Product {
    uint productId;
    string name;
    string description;
    uint price;
    address seller;
    bool isValidated;
}
```

### **Transaction Structure**
```solidity
struct Transaction {
    uint transactionId;
    uint productId;
    address buyer;
    address seller;
    uint price;
    uint timestamp;
}
```

### **Validator Profile Structure**
```solidity
struct ValidatorProfile {
    address validatorAddress;
    bool isVerified;
}
```

---

## **5. Smart Contract Workflow**

1. **Product Listing**:
   - The **SubmitterForValidation** role (backend-managed) lists products, marking them as “Pending Validation.”
2. **Product Validation**:
   - Validators register on-chain and are approved by an admin.
   - Once approved, validators can validate or reject listed products.
   - Validators receive notifications of new listings via the backend interface.
3. **Purchase Transaction**:
   - Buyers purchase validated products through the backend interface.
   - The transaction details, including buyer, seller, and product information, are logged on the blockchain.
4. **Confirmation (Escrow only)**:
   - If escrow is used, buyers confirm receipt through the backend, which releases funds to the seller.

---

## **6. Security Considerations**

- **Role-Based Access Control**: Only authorized addresses, managed by the backend, can perform specific actions. Validators interact directly on-chain.
- **Validator Approval**: Only verified validators, approved by admins, can validate products.
- **Data Immutability**: Ensure that transaction logs are immutable once completed, providing a secure and auditable history of buy, sell, and validation actions.
- **Reentrancy Guard**: Safeguard fund-related functions, especially in escrow, against reentrancy attacks.

---

## **7. Future Considerations**

- **Reputation System**: Consider implementing a reputation mechanism to incentivize reliable validators and buyers.
- **Scalable Notification System**: Integrate a scalable off-chain notification system for validators to keep track of pending products.