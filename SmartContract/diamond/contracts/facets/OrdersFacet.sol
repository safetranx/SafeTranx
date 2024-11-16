// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibDiamond } from "../libraries/LibDiamond.sol";

contract OrdersFacet {
    // Events
    event ProductListed(uint indexed _productId, string _name, uint _price);
    event OrderCreated(uint indexed _orderId, uint indexed _productId, address _buyer);
    event OrderValidated(uint indexed _orderId, bool _isValidated);
    event DeliveryAssigned(uint indexed _orderId, address _deliveryPerson);
    event DeliveryStatusUpdated(uint indexed _orderId, LibDiamond.OrderStatus _status);
    event OrderFinalized(uint indexed _orderId);
    event ValidatorApproved(address _validator);

    // Modifier to restrict access to Admins
    modifier onlyAdmin() {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(
            keccak256(abi.encodePacked(ds.roles[msg.sender])) == 
            keccak256(abi.encodePacked("Admin")), 
            "Not an admin"
        );
        _;
    }

    // Modifier to restrict access to Validators
    modifier onlyValidator() {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.validators[msg.sender], "Not an approved validator");
        _;
    }

    // Initialize function for the facet
    function initialize() external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.roles[msg.sender] = "Admin";
    }

    // Function to list a product
    function listProduct(string memory name, string memory description, uint price) external {
        require(price > 0, "Price must be greater than zero");
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.productCount++;
        ds.products[ds.productCount] = LibDiamond.Product(
            ds.productCount,
            name,
            description,
            price,
            msg.sender
        );
        
        emit ProductListed(ds.productCount, name, price);
    }

    // Function to create an order
    function createOrder(uint productId) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.products[productId].seller != address(0), "Product does not exist");
        
        ds.orderCount++;
        ds.orders[ds.orderCount] = LibDiamond.Order(
            ds.orderCount,
            productId,
            msg.sender,
            ds.products[productId].seller,
            address(0),
            address(0),
            false,
            LibDiamond.OrderStatus.Pending
        );
        
        emit OrderCreated(ds.orderCount, productId, msg.sender);
    }

    // Function to validate an order
    function validateOrder(uint orderId) external onlyValidator {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.Order storage order = ds.orders[orderId];
        
        require(order.status == LibDiamond.OrderStatus.Pending, "Order already processed");
        
        if (order.productId > 0) {
            order.isValidated = true;
            order.status = LibDiamond.OrderStatus.Validated;
            emit OrderValidated(orderId, true);
        } else {
            order.status = LibDiamond.OrderStatus.Rejected;
            emit OrderValidated(orderId, false);
        }
    }

    // Function to assign a delivery person
    function assignDelivery(uint orderId, address deliveryPersonAddress) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.orders[orderId].deliveryPerson = deliveryPersonAddress;
        ds.orders[orderId].status = LibDiamond.OrderStatus.DeliveryInProgress;

        emit DeliveryAssigned(orderId, deliveryPersonAddress);
    }

    // Function to update delivery status
    function updateDeliveryStatus(uint orderId, bool completed) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(
            msg.sender == ds.orders[orderId].deliveryPerson,
            "Not the assigned delivery person"
        );

        if (completed) {
            ds.orders[orderId].status = LibDiamond.OrderStatus.DeliveryCompleted;
            emit DeliveryStatusUpdated(orderId, LibDiamond.OrderStatus.DeliveryCompleted);
            
            _finalizeOrder(orderId);
        } else {
            ds.orders[orderId].status = LibDiamond.OrderStatus.DeliveryInProgress;
            emit DeliveryStatusUpdated(orderId, LibDiamond.OrderStatus.DeliveryInProgress);
        }
    }

    // Internal function to finalize the order
    function _finalizeOrder(uint orderId) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.orders[orderId].status = LibDiamond.OrderStatus.Finalized;

        emit OrderFinalized(orderId);
    }

    // Admin functions to manage validators and roles
    function approveValidator(address validatorAddress) external onlyAdmin {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.validators[validatorAddress] = true;
        
        emit ValidatorApproved(validatorAddress);
    }

    function assignRole(address userAddress, string memory role) external onlyAdmin {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.roles[userAddress] = role;
    }

    // View functions
    function getProduct(uint productId) external view returns (LibDiamond.Product memory) {
        return LibDiamond.diamondStorage().products[productId];
    }

    function getOrder(uint orderId) external view returns (LibDiamond.Order memory) {
        return LibDiamond.diamondStorage().orders[orderId];
    }

    function isValidator(address validator) external view returns (bool) {
        return LibDiamond.diamondStorage().validators[validator];
    }

    function getRole(address user) external view returns (string memory) {
        return LibDiamond.diamondStorage().roles[user];
    }

    function getProductCount() external view returns (uint) {
        return LibDiamond.diamondStorage().productCount;
    }

    function getOrderCount() external view returns (uint) {
        return LibDiamond.diamondStorage().orderCount;
    }
}

