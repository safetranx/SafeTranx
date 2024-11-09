// test/Orders.test.ts

import { expect } from "chai";
import { ethers } from "hardhat";

describe("Orders", function () {
    let Orders: any;
    let order: any;
    let owner: any, buyer: any, seller: any, validator: any, deliveryPerson: any;

    beforeEach(async function () {
        [owner, buyer, seller, validator, deliveryPerson] = await ethers.getSigners();

        // Deploy contract
        const OrdersFactory = await ethers.getContractFactory("Orders");
        order = await OrdersFactory.deploy();
        // await order.deployed();
    });

    describe("Product Listing", function () {
        it("should allow a submitter to list a product", async function () {
            await order.connect(seller).listProduct("Test Product", "This is a test product", ethers.parseEther("1"));
            const product = await order.products(1);
            expect(product.name).to.equal("Test Product");
            expect(product.price).to.equal(ethers.parseEther("1"));
            expect(product.seller).to.equal(seller.address);
        });

        it("should not allow listing by non-submitters", async function () {
            await expect(order.connect(buyer).listProduct("Unauthorized Product", "Should fail", ethers.parseEther("1")))
                .to.be.revertedWith("Not an approved submitter");
        });

        it("should revert when listing with zero price", async function () {
            await expect(order.connect(seller).listProduct("Free Product", "Should fail", 0))
                .to.be.revertedWith("Price must be greater than zero");
        });
    });

    describe("Order Creation", function () {
        beforeEach(async function () {
            await order.connect(seller).listProduct("Test Product", "This is a test product", ethers.parseEther("1"));
        });

        it("should allow a buyer to create an order", async function () {
            await order.connect(buyer).createOrder(1);
            const order_1 = await order.orders(1);
            expect(order_1.buyer).to.equal(buyer.address);
            expect(order_1.productId).to.equal(1);
            expect(order_1.status).to.equal(0); // Pending
        });

        it("should emit an OrderCreated event on order creation", async function () {
            await expect(order.connect(buyer).createOrder(1))
                .to.emit(order, "OrderCreated")
                .withArgs(1, 1, buyer.address);
        });

        it("should revert when creating an order for a non-existent product", async function () {
            await expect(order.connect(buyer).createOrder(999))
                .to.be.revertedWith("Product does not exist");
        });
    });

    describe("Order Validation", function () {
        beforeEach(async function () {
            await order.connect(seller).listProduct("Test Product", "This is a test product", ethers.parseEther("1"));
            await order.connect(buyer).createOrder(1);
            await order.approveValidator(validator.address); // Assuming admin approves validator
        });

        it("should allow a validator to validate an order", async function () {
            await order.connect(validator).validateOrder(1);
            const order_1 = await order.orders(1);
            expect(order_1.isValidated).to.equal(true);
            expect(order_1.status).to.equal(1); // Validated
        });

        it("should emit an OrderValidated event on validation", async function () {
            await expect(order.connect(validator).validateOrder(1))
                .to.emit(order, "OrderValidated")
                .withArgs(1, true);
        });

        it("should revert when validating an already validated order", async function () {
            await order.connect(validator).validateOrder(1); // First validation
            await expect(order.connect(validator).validateOrder(1))
                .to.be.revertedWith("Order already processed");
        });
    });

    describe("Delivery Assignment and Completion", function () {
        beforeEach(async function () {
            await order.connect(seller).listProduct("Test Product", "This is a test product", ethers.parseEther("1"));
            await order.connect(buyer).createOrder(1);
            await order.approveValidator(validator.address); // Assuming admin approves validator
            await order.connect(validator).validateOrder(1);
        });

        it("should allow seller to assign delivery person after validation", async function () {
            await order.assignDelivery(1, deliveryPerson.address);
            const order_1 = await order.orders(1);
            expect(order_1.deliveryPerson).to.equal(deliveryPerson.address);
        });

        it("should allow delivery person to update delivery status to completed", async function () {
            await order.assignDelivery(1, deliveryPerson.address);
            await order.connect(deliveryPerson).updateDeliveryStatus(1, true);

            const order_1 = await order.orders(1);
            expect(order_1.status).to.equal(4); // Delivery Completed
        });

        it("should revert if non-delivery person tries to update delivery status", async function () {
            await order.assignDelivery(1, deliveryPerson.address);

            // Trying to update by someone else
            await expect(order.connect(seller).updateDeliveryStatus(1, true))
                .to.be.revertedWith("Not the assigned delivery person");
        });
    });

    describe("Finalization of Orders", function () {
        beforeEach(async function () {
            await order.connect(seller).listProduct("Test Product", "This is a test product", ethers.parseEther("1"));
            await order.connect(buyer).createOrder(1);
            await order.approveValidator(validator.address); // Assuming admin approves validator
            await order.connect(validator).validateOrder(1);
            await order.assignDelivery(1, deliveryPerson.address);
            await order.connect(deliveryPerson).updateDeliveryStatus(1, true);
        });

        it("should finalize an order after confirmation from both seller and buyer", async function () {
            // Seller completes the order
            await order.connect(seller).completeOrder(1);

            const order_1 = await order.orders(1);

             // Buyer confirms completion
             await order.connect(buyer).confirmOrderCompletion(1);

             expect(order_1.status).to.equal(4); // Finalized
         });

         it('should emit OrderFinalized event on finalization', async function () {
             // Complete and confirm the order
             await order.connect(seller).completeOrder(1);
             
             // Confirm completion by buyer
             await expect(order.connect(buyer).confirmOrderCompletion(1))
                 .to.emit(order, "OrderFinalized")
                 .withArgs(1);
         });
         
         it('should revert if trying to finalize an already finalized order', async function() {
             // Complete and confirm the order first time
             await order.connect(seller).completeOrder(1);
             await order.connect(buyer).confirmOrderCompletion(1);

             // Try to finalize again
             await expect(order.connect(buyer).confirmOrderCompletion(1))
                 .to.be.revertedWith('Order already finalized');
         });
     });
});