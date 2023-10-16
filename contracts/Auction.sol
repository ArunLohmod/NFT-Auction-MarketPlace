//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Auction is IERC721Receiver {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    IERC721 public TokenX;

    address payable market;
    uint256 public marketFeePercent = 2;
    uint256 public auctionTime = uint256(5 days);

    Counters.Counter private totalAuctionId;
    EnumerableSet.UintSet TokenIds;

    enum auctionStatus {
        ACTIVE,
        OVER
    }

    struct auction {
        uint256 auctionId;
        uint256 start;
        uint256 end;
        uint256 tokenId;
        address auctioner;
        address highestBidder;
        uint256 highestBid;
        address[] prevBidders;
        uint256[] prevBidAmounts;
        auctionStatus status;
    }

    auction[] internal auctions;

    mapping(address => uint256[]) private conductedAuction;
    mapping(address => mapping(uint256 => uint256)) private participatedAuction; //address => auctionId => BidAmmount
    mapping(address => uint256[]) private history; // for tracking participated auctions
    mapping(address => uint256[]) private collectedArts;

    constructor(IERC721 _tokenx, address payable _market) {
        TokenX = _tokenx;
        market = _market;
    }

    function createSaleAuction(
        uint256 _tokenId,
        uint256 _price
    ) external returns (uint256) {
        require(TokenX.ownerOf(_tokenId) == msg.sender, "Auction your NFT");

        auction memory _auction = auction({
            auctionId: totalAuctionId.current(),
            start: block.timestamp,
            end: block.timestamp.add(auctionTime),
            tokenId: _tokenId,
            auctioner: msg.sender,
            highestBidder: msg.sender,
            highestBid: _price,
            prevBidders: new address[](0),
            prevBidAmounts: new uint256[](0),
            status: auctionStatus.ACTIVE
        });

        conductedAuction[msg.sender].push(totalAuctionId.current());

        auctions.push(_auction);

        TokenX.safeTransferFrom(address(msg.sender), address(this), _tokenId);

        totalAuctionId.increment();

        return uint256(totalAuctionId.current());
    }

    function placeBid(uint256 _auctionId) external payable returns (bool) {
        require(
            auctions[_auctionId].status == auctionStatus.ACTIVE,
            "auction is over!"
        );
        require(auctions[_auctionId].end > block.timestamp, "Auction Finished");
        require(auctions[_auctionId].auctioner != msg.sender, "Not allowed");
        require(
            auctions[_auctionId].highestBid < msg.value,
            "Place a higher Bid"
        );

        auction storage newAuction = auctions[_auctionId];

        newAuction.prevBidders.push(newAuction.highestBidder);
        newAuction.prevBidAmounts.push(newAuction.highestBid);

        if(newAuction.auctioner != newAuction.highestBidder){
           payable(newAuction.highestBidder).transfer(newAuction.highestBid);
        }

        participatedAuction[newAuction.highestBidder][_auctionId] = newAuction
            .highestBid;

        history[msg.sender].push(_auctionId);

        newAuction.highestBidder = msg.sender;

        newAuction.highestBid = msg.value;

        return true;
    }

    function finishAuction(uint256 _auctionId) external {
        auction storage newAuction = auctions[_auctionId];

        require(newAuction.auctioner == msg.sender, "only auctioner");

        require(
            uint256(newAuction.end) >= uint256(block.number),
            "already Finshed"
        );

        newAuction.end = uint32(block.number);

        newAuction.status = auctionStatus.OVER;

        uint256 marketFee = newAuction.highestBid.mul(marketFeePercent).div(
            100
        );

        if (newAuction.prevBidders.length > 0) {

            collectedArts[newAuction.highestBidder].push(newAuction.tokenId);

            payable(msg.sender).transfer(newAuction.highestBid.sub(marketFee)); // msg.sender is auctioner

            market.transfer(marketFee);

            TokenX.safeTransferFrom(
                address(this),
                newAuction.highestBidder,
                newAuction.tokenId
            );
        }
    }

    function auctionStatusCheck(
        uint256 _auctionId
    ) external view returns (bool) {
        if (auctions[_auctionId].end > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    function auctionInfo(
        uint256 _auctionId
    )
        external
        view
        returns (
            uint256 auctionId,
            uint256 start,
            uint256 end,
            uint256 tokenId,
            address auctioner,
            address highestBidder,
            uint256 highestBid,
            uint256 status
        )
    {
        auction storage newAuction = auctions[_auctionId];

        auctionId = _auctionId;

        start = newAuction.start;

        end = newAuction.end;

        tokenId = newAuction.tokenId;

        auctioner = newAuction.auctioner;

        highestBidder = newAuction.highestBidder;

        highestBid = newAuction.highestBid;

        status = uint256(newAuction.status);
    }

    function bidHistory(
        uint256 _auctionId
    ) external view returns (address[] memory, uint256[] memory) {
        return (
            auctions[_auctionId].prevBidders,
            auctions[_auctionId].prevBidAmounts
        );
    }

    function participatedAuctions(
        address _user
    ) external view returns (uint256[] memory) {
        return history[_user];
    }

    function totalAuction() external view returns (uint256) {
        return auctions.length;
    }

    function conductedAuctions(
        address _user
    ) external view returns (uint256[] memory) {
        return conductedAuction[_user];
    }

    function collectedArtsList(
        address _user
    ) external view returns (uint256[] memory) {
        return collectedArts[_user];
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external override returns (bytes4) {
        require(
            msg.sender == address(TokenX),
            "received from unauthenticated contract"
        );

        TokenIds.add(_tokenId);

        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
