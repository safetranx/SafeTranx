// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibDiamond } from "../libraries/LibDiamond.sol";

contract OrdersFacet {
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

    // Storage struct for the Diamond
    struct OrderStorage {
        mapping(uint => Product) products;
        mapping(uint => Order) orders;
        mapping(address => bool) validators;
        mapping(address => string) roles;
        uint productCount;
        uint orderCount;
    }

    // Events
    event ProductListed(uint indexed _productId, string _name, uint _price);
    event OrderCreated(uint indexed _orderId, uint indexed _productId, address _buyer);
    event OrderValidated(uint indexed _orderId, bool _isValidated);
    event DeliveryAssigned(uint indexed _orderId, address _deliveryPerson);
    event DeliveryStatusUpdated(uint indexed _orderId, OrderStatus _status);
    event OrderFinalized(uint indexed _orderId);
    event ValidatorApproved(address _validator);

    // Diamond storage position
    bytes32 constant ORDERS_STORAGE_POSITION = keccak256("diamond.orders.storage");

    function orderStorage() internal pure returns (OrderStorage storage ds) {
        bytes32 position = ORDERS_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // Modifier to restrict access to Admins
    modifier onlyAdmin() {
        OrderStorage storage s = orderStorage();
        require(
            keccak256(abi.encodePacked(s.roles[msg.sender])) == 
            keccak256(abi.encodePacked("Admin")), 
            "Not an admin"
        );
        _;
    }

    // Modifier to restrict access to Validators
    modifier onlyValidator() {
        OrderStorage storage s = orderStorage();
        require(s.validators[msg.sender], "Not an approved validator");
        _;
    }

    // Initialize function for the facet
    function initialize() external {
        LibDiamond.enforceIsContractOwner();
        OrderStorage storage s = orderStorage();
        s.roles[msg.sender] = "Admin";
    }

    // Function to list a product
    function listProduct(string memory name, string memory description, uint price) external {
        require(price > 0, "Price must be greater than zero");
        OrderStorage storage s = orderStorage();
        s.productCount++;
        s.products[s.productCount] = Product(
            s.productCount,
            name,
            description,
            price,
            msg.sender
        );
        
        emit ProductListed(s.productCount, name, price);
    }

    // Function to create an order
    function createOrder(uint productId) external {
        OrderStorage storage s = orderStorage();
        require(s.products[productId].seller != address(0), "Product does not exist");
        
        s.orderCount++;
        s.orders[s.orderCount] = Order(
            s.orderCount,
            productId,
            msg.sender,
            s.products[productId].seller,
            address(0),
            address(0),
            false,
            OrderStatus.Pending
        );
        
        emit OrderCreated(s.orderCount, productId, msg.sender);
    }

    // Function to validate an order
    function validateOrder(uint orderId) external onlyValidator {
        OrderStorage storage s = orderStorage();
        Order storage order = s.orders[orderId];
        
        require(order.status == OrderStatus.Pending, "Order already processed");
        
        if (order.productId > 0) {
            order.isValidated = true;
            order.status = OrderStatus.Validated;
            emit OrderValidated(orderId, true);
        } else {
            order.status = OrderStatus.Rejected;
            emit OrderValidated(orderId, false);
        }
    }

    // Function to assign a delivery person
    function assignDelivery(uint orderId, address deliveryPersonAddress) external {
        OrderStorage storage s = orderStorage();
        s.orders[orderId].deliveryPerson = deliveryPersonAddress;
        s.orders[orderId].status = OrderStatus.DeliveryInProgress;

        emit DeliveryAssigned(orderId, deliveryPersonAddress);
    }

    // Function to update delivery status
    function updateDeliveryStatus(uint orderId, bool completed) external {
        OrderStorage storage s = orderStorage();
        require(
            msg.sender == s.orders[orderId].deliveryPerson,
            "Not the assigned delivery person"
        );

        if (completed) {
            s.orders[orderId].status = OrderStatus.DeliveryCompleted;
            emit DeliveryStatusUpdated(orderId, OrderStatus.DeliveryCompleted);
            
            _finalizeOrder(orderId);
        } else {
            s.orders[orderId].status = OrderStatus.DeliveryInProgress;
            emit DeliveryStatusUpdated(orderId, OrderStatus.DeliveryInProgress);
        }
    }

    // Internal function to finalize the order
    function _finalizeOrder(uint orderId) internal {
        OrderStorage storage s = orderStorage();
        s.orders[orderId].status = OrderStatus.Finalized;

        emit OrderFinalized(orderId);
    }

    // Admin functions to manage validators and roles
    function approveValidator(address validatorAddress) external onlyAdmin {
        OrderStorage storage s = orderStorage();
        s.validators[validatorAddress] = true;
        
        emit ValidatorApproved(validatorAddress);
    }

    function assignRole(address userAddress, string memory role) external onlyAdmin {
        OrderStorage storage s = orderStorage();
        s.roles[userAddress] = role;
    }

    // View functions
    function getProduct(uint productId) external view returns (Product memory) {
        return orderStorage().products[productId];
    }

    function getOrder(uint orderId) external view returns (Order memory) {
        return orderStorage().orders[orderId];
    }

    function isValidator(address validator) external view returns (bool) {
        return orderStorage().validators[validator];
    }

    function getRole(address user) external view returns (string memory) {
        return orderStorage().roles[user];
    }

    function getProductCount() external view returns (uint) {
        return orderStorage().productCount;
    }

    function getOrderCount() external view returns (uint) {
        return orderStorage().orderCount;
    }
}

