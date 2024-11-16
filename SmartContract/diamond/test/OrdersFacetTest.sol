// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/facets/OrdersFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";

import "./helpers/DiamondUtils.sol";

contract OrdersFacetTest is DiamondUtils, IDiamondCut {
    Diamond diamond;
    OrdersFacet ordersFacet;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupeFacet;
    OwnershipFacet ownershipFacet;

    address owner = address(0x1234);
    address seller = address(0x5678);
    address buyer = address(0x9ABC);
    address validator = address(0xDEF0);
    address deliveryPerson = address(0x4321);

    event ProductListed(uint indexed _productId, string _name, uint _price);
    event OrderCreated(uint indexed _orderId, uint indexed _productId, address _buyer);
    event OrderValidated(uint indexed _orderId, bool _isValidated);
    event DeliveryAssigned(uint indexed _orderId, address _deliveryPerson);
    event DeliveryStatusUpdated(uint indexed _orderId, OrdersFacet.OrderStatus _status);
    event OrderFinalized(uint indexed _orderId);
    event ValidatorApproved(address _validator);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy Diamond and facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        dLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        ordersFacet = new OrdersFacet();

        // Build cut struct
        FacetCut[] memory cut = new FacetCut[](3);
        
        cut[0] = FacetCut({
            facetAddress: address(dLoupeFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(ownershipFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(ordersFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OrdersFacet")
        });

        // Initialize OrdersFacet
        bytes memory initData = abi.encodeWithSelector(
            OrdersFacet.initialize.selector
        );

        IDiamondCut(address(diamond)).diamondCut(cut, address(ordersFacet), initData);
        vm.stopPrank();
    }

    function testInitialization() public view {
        assertEq(OrdersFacet(address(diamond)).getRole(owner), "Admin");
    }

    function testListProduct() public {
        string memory name = "Test Product";
        string memory description = "Test Description";
        uint price = 100;

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit ProductListed(1, name, price);
        
        OrdersFacet(address(diamond)).listProduct(name, description, price);
        
        OrdersFacet.Product memory product = OrdersFacet(address(diamond)).getProduct(1);
        assertEq(product.name, name);
        assertEq(product.description, description);
        assertEq(product.price, price);
        assertEq(product.seller, seller);
        vm.stopPrank();
    }

    function testCreateOrder() public {
        // First list a product
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);

        // Create order
        vm.startPrank(buyer);
        vm.expectEmit(true, true, true, false);
        emit OrderCreated(1, 1, buyer);
        
        OrdersFacet(address(diamond)).createOrder(1);
        
        OrdersFacet.Order memory order = OrdersFacet(address(diamond)).getOrder(1);
        assertEq(order.buyer, buyer);
        assertEq(order.seller, seller);
        assertEq(uint(order.status), uint(OrdersFacet.OrderStatus.Pending));
        vm.stopPrank();
    }

    function testApproveAndValidateOrder() public {
        // Setup product and order
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);

        // Approve validator
        vm.prank(owner);
        OrdersFacet(address(diamond)).approveValidator(validator);
        assertTrue(OrdersFacet(address(diamond)).isValidator(validator));

        // Validate order
        vm.startPrank(validator);
        vm.expectEmit(true, false, false, true);
        emit OrderValidated(1, true);
        
        OrdersFacet(address(diamond)).validateOrder(1);
        
        OrdersFacet.Order memory order = OrdersFacet(address(diamond)).getOrder(1);
        assertTrue(order.isValidated);
        assertEq(uint(order.status), uint(OrdersFacet.OrderStatus.Validated));
        vm.stopPrank();
    }

    function testDeliveryFlow() public {
        // Setup product, order and validation
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        
        vm.prank(owner);
        OrdersFacet(address(diamond)).approveValidator(validator);
        
        vm.prank(validator);
        OrdersFacet(address(diamond)).validateOrder(1);

        // Assign delivery
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit DeliveryAssigned(1, deliveryPerson);
        
        OrdersFacet(address(diamond)).assignDelivery(1, deliveryPerson);
        vm.stopPrank();

        // Update delivery status
        vm.startPrank(deliveryPerson);
        vm.expectEmit(true, false, false, true);
        emit DeliveryStatusUpdated(1, OrdersFacet.OrderStatus.DeliveryCompleted);
        
        OrdersFacet(address(diamond)).updateDeliveryStatus(1, true);
        
        OrdersFacet.Order memory order = OrdersFacet(address(diamond)).getOrder(1);
        assertEq(uint(order.status), uint(OrdersFacet.OrderStatus.Finalized));
        vm.stopPrank();
    }

    function testFailInvalidValidator() public {
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);

        vm.expectRevert("Not an approved validator");
        OrdersFacet(address(diamond)).validateOrder(1);
    }

    function testFailUnauthorizedDeliveryUpdate() public {
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        
        vm.prank(owner);
        OrdersFacet(address(diamond)).assignDelivery(1, deliveryPerson);

        // Complete the previous test
        vm.prank(buyer);
        vm.expectRevert("Not the assigned delivery person");
        OrdersFacet(address(diamond)).updateDeliveryStatus(1, true);
    }

    function testFailCreateOrderInvalidProduct() public {
        vm.expectRevert("Product does not exist");
        OrdersFacet(address(diamond)).createOrder(1);
    }

    function testFailListProductZeroPrice() public {
        vm.expectRevert("Price must be greater than zero");
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 0);
    }

    function testFailValidateProcessedOrder() public {
        // Setup product and order
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Test Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);

        // Approve validator
        vm.prank(owner);
        OrdersFacet(address(diamond)).approveValidator(validator);

        // First validation
        vm.prank(validator);
        OrdersFacet(address(diamond)).validateOrder(1);

        // Attempt second validation
        vm.prank(validator);
        vm.expectRevert("Order already processed");
        OrdersFacet(address(diamond)).validateOrder(1);
    }

    function testRoleAssignment() public {
        vm.startPrank(owner);
        OrdersFacet(address(diamond)).assignRole(buyer, "Customer");
        assertEq(OrdersFacet(address(diamond)).getRole(buyer), "Customer");
        vm.stopPrank();
    }

    function testFailNonAdminRoleAssignment() public {
        vm.prank(buyer);
        vm.expectRevert("Not an admin");
        OrdersFacet(address(diamond)).assignRole(seller, "Seller");
    }

    function testFailNonAdminValidatorApproval() public {
        vm.prank(buyer);
        vm.expectRevert("Not an admin");
        OrdersFacet(address(diamond)).approveValidator(validator);
    }

    function testCompleteOrderLifecycle() public {
        // 1. List Product
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Complete Test Product", "Full Lifecycle Test", 100);
        
        // 2. Create Order
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        
        // 3. Approve and Assign Validator
        vm.startPrank(owner);
        OrdersFacet(address(diamond)).approveValidator(validator);
        OrdersFacet(address(diamond)).assignRole(validator, "Validator");
        vm.stopPrank();
        
        // 4. Validate Order
        vm.prank(validator);
        OrdersFacet(address(diamond)).validateOrder(1);
        
        // 5. Assign Delivery
        vm.prank(owner);
        OrdersFacet(address(diamond)).assignDelivery(1, deliveryPerson);
        
        // 6. Start Delivery
        vm.prank(deliveryPerson);
        OrdersFacet(address(diamond)).updateDeliveryStatus(1, false);
        
        // Verify status is DeliveryInProgress
        OrdersFacet.Order memory orderInProgress = OrdersFacet(address(diamond)).getOrder(1);
        assertEq(uint(orderInProgress.status), uint(OrdersFacet.OrderStatus.DeliveryInProgress));
        
        // 7. Complete Delivery
        vm.prank(deliveryPerson);
        OrdersFacet(address(diamond)).updateDeliveryStatus(1, true);
        
        // 8. Verify Final State
        OrdersFacet.Order memory finalOrder = OrdersFacet(address(diamond)).getOrder(1);
        assertEq(uint(finalOrder.status), uint(OrdersFacet.OrderStatus.Finalized));
        assertEq(finalOrder.buyer, buyer);
        assertEq(finalOrder.seller, seller);
        assertEq(finalOrder.deliveryPerson, deliveryPerson);
        assertTrue(finalOrder.isValidated);
    }

    function testProductCountIncrement() public {
        uint initialCount = OrdersFacet(address(diamond)).getProductCount();
        
        vm.startPrank(seller);
        OrdersFacet(address(diamond)).listProduct("Product 1", "Description 1", 100);
        OrdersFacet(address(diamond)).listProduct("Product 2", "Description 2", 200);
        vm.stopPrank();
        
        assertEq(OrdersFacet(address(diamond)).getProductCount(), initialCount + 2);
    }

    function testOrderCountIncrement() public {
        // List products
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Description", 100);
        
        uint initialCount = OrdersFacet(address(diamond)).getOrderCount();
        
        vm.startPrank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        OrdersFacet(address(diamond)).createOrder(1); // Can order same product multiple times
        vm.stopPrank();
        
        assertEq(OrdersFacet(address(diamond)).getOrderCount(), initialCount + 2);
    }

    function testMultipleOrdersMultipleProducts() public {
        // List multiple products
        vm.startPrank(seller);
        OrdersFacet(address(diamond)).listProduct("Product 1", "Description 1", 100);
        OrdersFacet(address(diamond)).listProduct("Product 2", "Description 2", 200);
        vm.stopPrank();
        
        // Create multiple orders
        vm.startPrank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        OrdersFacet(address(diamond)).createOrder(2);
        vm.stopPrank();
        
        // Verify order details
        OrdersFacet.Order memory order1 = OrdersFacet(address(diamond)).getOrder(1);
        OrdersFacet.Order memory order2 = OrdersFacet(address(diamond)).getOrder(2);
        
        assertEq(order1.productId, 1);
        assertEq(order2.productId, 2);
        assertEq(order1.buyer, buyer);
        assertEq(order2.buyer, buyer);
    }

    function testRejectOrder() public {
        // Setup product with ID 0 to trigger rejection
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Test Product", "Description", 100);
        
        vm.prank(buyer);
        OrdersFacet(address(diamond)).createOrder(1);
        
        vm.prank(owner);
        OrdersFacet(address(diamond)).approveValidator(validator);
        
        // Validate order - should reject due to modification of validation logic
        vm.prank(validator);
        OrdersFacet(address(diamond)).validateOrder(2);
        
        
        OrdersFacet.Order memory order = OrdersFacet(address(diamond)).getOrder(2);
        assertFalse(order.isValidated);
    }

    // Fuzz test for product pricing
    function testFuzzProductPricing(uint256 price) public {
        vm.assume(price > 0 && price < type(uint256).max);
        
        vm.prank(seller);
        OrdersFacet(address(diamond)).listProduct("Fuzz Test Product", "Description", price);
        
        OrdersFacet.Product memory product = OrdersFacet(address(diamond)).getProduct(1);
        assertEq(product.price, price);
    }

     function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}