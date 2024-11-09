// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Orders {
    // Enum for order status
    enum OrderStatus {
        Pending,
        Validated,
        DeliveryInProgress,
        DeliveryCompleted,
        Finalized,
        Rejected
    }

    // Struct for Product
    struct Product {
        uint productId;
        string name;
        string description;
        uint price;
        address seller;
    }

    // Struct for Order
    struct Order {
        uint orderId;
        uint productId;
        address buyer;
        address seller;
        address validator;
        address deliveryPerson;
        bool isValidated;
        OrderStatus status;
    }

    // Mappings
    mapping(uint => Product) public products; // productId => Product
    mapping(uint => Order) public orders; // orderId => Order
    mapping(address => bool) public validators; // approved validators
    mapping(address => string) public roles; // user roles

    uint public productCount = 0; // Counter for product IDs
    uint public orderCount = 0; // Counter for order IDs

    // Events
    event ProductListed(uint indexed _productId, string _name, uint _price);
    event OrderCreated(uint indexed _orderId, uint indexed _productId, address _buyer);
    event OrderValidated(uint indexed _orderId, bool _isValidated);
    event DeliveryAssigned(uint indexed _orderId, address _deliveryPerson);
    event DeliveryStatusUpdated(uint indexed _orderId, OrderStatus _status);
    event OrderFinalized(uint indexed _orderId);
    event ValidatorApproved(address _validator);

    // Modifier to restrict access to Admins
    modifier onlyAdmin() {
        require(keccak256(abi.encodePacked(roles[msg.sender])) == keccak256(abi.encodePacked("Admin")), "Not an admin");
        _;
    }

    // Modifier to restrict access to Validators
    modifier onlyValidator() {
        require(validators[msg.sender], "Not an approved validator");
        _;
    }

    // Function to list a product
    function listProduct(string memory name, string memory description, uint price) external {
        productCount++;
        products[productCount] = Product(productCount, name, description, price, msg.sender);
        
        emit ProductListed(productCount, name, price);
    }

    // Function to create an order
    function createOrder(uint productId) external {
        require(products[productId].seller != address(0), "Product does not exist");
        
        orderCount++;
        orders[orderCount] = Order(orderCount, productId, msg.sender, products[productId].seller, address(0), address(0), false, OrderStatus.Pending);
        
        emit OrderCreated(orderCount, productId, msg.sender);
        
        // Notify validators (this could be an off-chain notification)
    }

    // Function to validate an order
    function validateOrder(uint orderId) external onlyValidator {
        Order storage order = orders[orderId];
        
        require(order.status == OrderStatus.Pending, "Order already processed");
        
        if (order.productId > 0) { // Assuming validation criteria is met
            order.isValidated = true;
            order.status = OrderStatus.Validated;
            emit OrderValidated(orderId, true);
            
            // Assign delivery person (could be done by seller)
            assignDelivery(orderId, msg.sender); 
        } else {
            order.status = OrderStatus.Rejected;
            emit OrderValidated(orderId, false);
        }
    }

    // Function to assign a delivery person
    function assignDelivery(uint orderId, address deliveryPersonAddress) internal {
        orders[orderId].deliveryPerson = deliveryPersonAddress;
        orders[orderId].status = OrderStatus.DeliveryInProgress;

        emit DeliveryAssigned(orderId, deliveryPersonAddress);
    }

    // Function to update delivery status
    function updateDeliveryStatus(uint orderId, bool completed) external {
        require(msg.sender == orders[orderId].deliveryPerson, "Not the assigned delivery person");

        if (completed) {
            orders[orderId].status = OrderStatus.DeliveryCompleted;
            emit DeliveryStatusUpdated(orderId, OrderStatus.DeliveryCompleted);
            
            finalizeOrder(orderId);
        } else {
            orders[orderId].status = OrderStatus.DeliveryInProgress;
            emit DeliveryStatusUpdated(orderId, OrderStatus.DeliveryInProgress);
        }
    }

    // Function to finalize the order
    function finalizeOrder(uint orderId) internal {
        orders[orderId].status = OrderStatus.Finalized;

        emit OrderFinalized(orderId);
        
        // Additional logic for payment settlement can be added here.
    }

    // Admin functions to manage validators and roles
    function approveValidator(address validatorAddress) external onlyAdmin {
        validators[validatorAddress] = true;
        
        emit ValidatorApproved(validatorAddress);
    }

    function assignRole(address userAddress, string memory role) external onlyAdmin {
        roles[userAddress] = role; 
    }
}