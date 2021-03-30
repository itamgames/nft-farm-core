const { expect, assert } = require('chai');
const Web3 = require('web3');
const BEP20Data = require('./BEP20');
const { soliditySha3 } = require("web3-utils");

const web3 = new Web3();

describe('NFT Farm Exchange', function() {
    before(async function() {
        [
            this.exchangeOwner,
            this.team,
            this.sellerA,
            this.buyerA,
            this.sellerB,
            this.buyerB,
            this.nftOwner,
        ] = await ethers.getSigners();

        const NFTFarmExchangeFactory = await ethers.getContractFactory('NFTFarmExchange', this.exchangeOwner);
        this.NFTFarmExchange = await NFTFarmExchangeFactory.deploy(this.team.address, 10);
        await this.NFTFarmExchange.deployed();

        const ERC721TradableFactory = await ethers.getContractFactory('ERC721Tradable', this.nftOwner);
        this.ERC721Tradable = await ERC721TradableFactory.deploy('ITAM', 'ITAM', 'https://itam.network/token/', this.NFTFarmExchange.address);
        await this.ERC721Tradable.deployed();

        const BEP20Factory = new ethers.ContractFactory(BEP20Data.abi, BEP20Data.bytecode, this.nftOwner);
        this.BEP20 = await BEP20Factory.deploy('ITAM', 'ITAM');
        await this.BEP20.deployed();

        await this.BEP20.mint(this.buyerA.address, web3.utils.toWei('1000'));
        await this.BEP20.mint(this.buyerB.address, web3.utils.toWei('1000'));
    });

    it('Swap ERC721 for ERC20 Token in seller transaction', async function () {
        const tokenId = 1;
        await this.ERC721Tradable.mintTo(this.sellerA.address);
        
        const target = this.ERC721Tradable.address;
        const targetCalldata = (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', [this.sellerA.address, this.buyerA.address, tokenId]);
        const paymentToken = this.BEP20.address;
        const priceAmount = web3.utils.toWei('100');
        const feePercent = '10';
        const expirationBlocks = ['0', '0'];
        const nonces = [new Date().getTime(), new Date().getTime()];
        
        const sellHash = soliditySha3(this.sellerA.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[0], nonces[0]);
        const buyHash = soliditySha3(this.buyerA.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[1], nonces[1]);
        const signatures = [
            await this.sellerA._signer.signMessage(ethers.utils.arrayify(sellHash)),
            await this.buyerA._signer.signMessage(ethers.utils.arrayify(buyHash)),
        ];

        await this.NFTFarmExchange.connect(this.sellerA).createProxy();
        await this.NFTFarmExchange.connect(this.buyerA).createProxy();

        const sellerProxy = await this.NFTFarmExchange.proxies(this.sellerA.address);
        const buyerProxy = await this.NFTFarmExchange.proxies(this.buyerA.address);

        await this.BEP20.connect(this.buyerA).approve(buyerProxy, web3.utils.toWei('1000'));
        await this.ERC721Tradable.connect(this.sellerA).approve(sellerProxy, tokenId);

        await this.NFTFarmExchange.connect(this.sellerA).exchange(
            target,
            targetCalldata,
            paymentToken,
            priceAmount,
            feePercent,
            [this.sellerA.address, this.buyerA.address],
            [0x0, 0x0],
            expirationBlocks,
            nonces,
            signatures,
        );

        assert(await this.ERC721Tradable.ownerOf(tokenId) === this.buyerA.address, 'failed to exchange');
        assert((await this.BEP20.balanceOf(this.sellerA.address)).toString() === web3.utils.toWei('90'), 'wrong balanceOf seller');
        assert((await this.BEP20.balanceOf(this.team.address)).toString() === web3.utils.toWei('10'), 'wrong balanceOf team');
    });

    it('Swap NFT for ERC20 Token in buyer transaction', async function () {
        const tokenId = 2;
        await this.ERC721Tradable.mintTo(this.sellerB.address);

        const target = this.ERC721Tradable.address;
        const targetCalldata = (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', [this.sellerB.address, this.buyerB.address, tokenId]);
        const paymentToken = this.BEP20.address;
        const priceAmount = web3.utils.toWei('100');
        const feePercent = '10';
        const expirationBlocks = ['0', '0'];
        const nonces = [new Date().getTime(), new Date().getTime()];
        
        const sellHash = soliditySha3(this.sellerB.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[0], nonces[0]);
        const buyHash = soliditySha3(this.buyerB.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[1], nonces[1]);
        const signatures = [
            await this.sellerB._signer.signMessage(ethers.utils.arrayify(sellHash)),
            await this.buyerB._signer.signMessage(ethers.utils.arrayify(buyHash)),
        ];

        await this.NFTFarmExchange.connect(this.sellerB).createProxy();
        await this.NFTFarmExchange.connect(this.buyerB).createProxy();

        const sellerProxy = await this.NFTFarmExchange.proxies(this.sellerB.address);
        const buyerProxy = await this.NFTFarmExchange.proxies(this.buyerB.address);

        await this.BEP20.connect(this.buyerB).approve(buyerProxy, web3.utils.toWei('1000'));
        await this.ERC721Tradable.connect(this.sellerB).approve(sellerProxy, tokenId);

        await this.NFTFarmExchange.connect(this.buyerB).exchange(
            target,
            targetCalldata,
            paymentToken,
            priceAmount,
            feePercent,
            [this.sellerB.address, this.buyerB.address],
            [0x0, 0x0],
            expirationBlocks,
            nonces,
            signatures,
        );

        assert(await this.ERC721Tradable.ownerOf(tokenId) === this.buyerB.address, 'failed to exchange');
        assert((await this.BEP20.balanceOf(this.sellerB.address)).toString() === web3.utils.toWei('90'), 'wrong balanceOf seller');
        assert((await this.BEP20.balanceOf(this.team.address)).toString() === web3.utils.toWei('20'), 'wrong balanceOf team');
    });

    it('fail to exchange closed order', async function () {
        const tokenId = 3;
        await this.ERC721Tradable.mintTo(this.sellerA.address); 

        const target = this.ERC721Tradable.address;
        const targetCalldata = (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', [this.sellerA.address, this.buyerA.address, tokenId]);
        const paymentToken = this.BEP20.address;
        const priceAmount = web3.utils.toWei('100');
        const feePercent = '10';
        const expirationBlocks = ['0', '0'];
        const nonces = [new Date().getTime(), new Date().getTime()];
        
        const sellHash = soliditySha3(this.sellerA.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[0], nonces[0]);
        const buyHash = soliditySha3(this.buyerA.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[1], nonces[1]);
        const signatures = [
            await this.sellerA._signer.signMessage(ethers.utils.arrayify(sellHash)),
            await this.buyerA._signer.signMessage(ethers.utils.arrayify(buyHash)),
        ];

        await this.NFTFarmExchange.connect(this.sellerA).cancelOrder(target, targetCalldata, paymentToken, priceAmount, feePercent, this.sellerA.address, expirationBlocks[0], nonces[0], signatures[0]);

        const sellerProxy = await this.NFTFarmExchange.proxies(this.sellerA.address);
        const buyerProxy = await this.NFTFarmExchange.proxies(this.buyerA.address);

        await this.BEP20.connect(this.buyerA).approve(buyerProxy, web3.utils.toWei('1000'));
        await this.ERC721Tradable.connect(this.sellerA).approve(sellerProxy, tokenId);

        expect(this.NFTFarmExchange.connect(this.sellerA).exchange(
            target,
            targetCalldata,
            paymentToken,
            priceAmount,
            feePercent,
            [this.sellerA.address, this.buyerA.address],
            [0x0, 0x0],
            expirationBlocks,
            nonces,
            signatures,
        )).to.be.revertedWith('closed seller order');
    });

    it('Swap NFT for ERC20 Token with replacement calldata', async function () {
        const tokenId = 4;
        await this.ERC721Tradable.mintTo(this.sellerB.address);

        // for offer signer
        const zeroAddress = '0x0000000000000000000000000000000000000000';

        const target = this.ERC721Tradable.address;
        const targetCalldata = (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', [zeroAddress, this.buyerB.address, tokenId]);
        const paymentToken = this.BEP20.address;
        const priceAmount = web3.utils.toWei('100');
        const feePercent = '10';
        const expirationBlocks = ['0', '0'];
        const nonces = [new Date().getTime(), new Date().getTime()];
        
        const sellHash = soliditySha3(this.sellerB.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[0], nonces[0]);
        const buyHash = soliditySha3(this.buyerB.address, target, targetCalldata, paymentToken, priceAmount, feePercent, expirationBlocks[1], nonces[1]);
        const signatures = [
            await this.sellerB._signer.signMessage(ethers.utils.arrayify(sellHash)),
            await this.buyerB._signer.signMessage(ethers.utils.arrayify(buyHash)),
        ];

        const sellerProxy = await this.NFTFarmExchange.proxies(this.sellerB.address);
        const buyerProxy = await this.NFTFarmExchange.proxies(this.buyerB.address);

        await this.BEP20.connect(this.buyerB).approve(buyerProxy, web3.utils.toWei('1000'));
        await this.ERC721Tradable.connect(this.sellerB).approve(sellerProxy, tokenId);

        await this.NFTFarmExchange.connect(this.buyerB).exchange(
            target,
            targetCalldata,
            paymentToken,
            priceAmount,
            feePercent,
            [this.sellerB.address, this.buyerB.address],
            // TODO: 
            [
                (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', [this.sellerB.address, zeroAddress, 0]),
                (new ethers.utils.Interface(['function transferFrom(address from, address to, uint256 tokenId)'])).encodeFunctionData('transferFrom', ['0x1111111111111111111111111111111111111111', zeroAddress, 0])
            ],
            expirationBlocks,
            nonces,
            signatures,
        );

        assert(await this.ERC721Tradable.ownerOf(tokenId) === this.buyerB.address, 'failed to exchange');
        assert((await this.BEP20.balanceOf(this.sellerB.address)).toString() === web3.utils.toWei('180'), 'wrong balanceOf seller');
        assert((await this.BEP20.balanceOf(this.team.address)).toString() === web3.utils.toWei('30'), 'wrong balanceOf team');
    });
});