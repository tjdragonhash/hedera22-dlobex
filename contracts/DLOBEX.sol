//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "hardhat/console.sol";

/**
 * Implementation of a CLOB for Hedera 22
 * To add, if time permits:
 * 
 * - Fees
 * - Misbehavior penalty
 * - Limit order time based
 * - Price diff checks 
 * 
 * tjdragonhash at gmail dot com
 */
contract DLOBEX is Ownable {
    // Owner of this smart contract
    address private _owner;
    // Base Token To Trade/Swap
    IERC20 private _token_base;
    // Term Token to Trade/Swap
    IERC20 private _token_term;
    // Participants
    mapping(address => bool) private _participants;
    // Is trading allowed
    bool private _trading_allowed = false;
    // Fixed fee for the base token
    uint256 _base_fee = 0;
    // Fixed fee fpr the term token
    uint256 _term_fee = 0;
    // Last traded price
    uint256 _last_traded_price = 0;

    // Order Structure
    struct Order {
        uint256 id_int; // Internal Order Id
        uint256 id_ext; // External Order Id
        address owner; // Owner
        bool is_buy; // Is this a Buy or Sell 
        uint256 size; // Size
        uint256 price; // Price (0 for Market Orders)
    }

    // Settlement Structure
    struct Settlement {
        address adr1;
        uint256 token1_amount;
        address token1;
        address adr2;
        uint256 token2_amount;
        address token2;
        uint256 price;
    }

    // Internal order id - continuously increments
    uint256 private _order_count = 1;
    // Mapping of internal order id to orders
    mapping(uint256 => Order) private _orders;
    // Mapping of external order id to internal order id
    mapping(uint256 => uint256) private _order_ext_int_mapping;
     // Mapping of Price to Array of order ids
    mapping(uint256 => uint256[]) private _buy_list;
    // Sorted on insert list of prices: 12, 10, 8
    uint256[] private _buy_prices;
     // Mapping of Price to Array of order ids
    mapping(uint256 => uint256[]) private _sell_list;
    // Sorted on insert list of prices: 13, 15, 18
    uint256[] private _sell_prices;
    // Settlements instructions are stored for debugging purpose
    Settlement[] private _settlements;

    // Set of events
    event ParticipantAddedEvent(address adr);
    event ParticipantRemovedEvent(address adr);
    event TradingStoppedEvent();
    event TradingStartedEvent();
    event OrderPlacedEvent(Order order);
    event OrderUpdatedEvent(Order order);
    event OrderRemovedEvent(Order order);
    event SettlementInstruction(address adr1, uint256 token1_amount, address token1, address adr2, uint256 token2_amount, address token2, uint256 price);

    modifier tradingAllowed {
        _debug = "";
        require(_trading_allowed, "Trading has been disabled");
        require(_participants[msg.sender], "Participant is not allowed");
        _;
    }

    modifier onlyParticipant {
         require(_participants[msg.sender] || msg.sender == _owner, "Participant is not allowed");
        _;
    }

    // Can be useful to get messages remotely for testing purposes
    string private _debug;

    // This contract is instantiated for a given trading pair of ERC 20 tokens
    constructor(address token_base_address, address token_term_address) {
        // console.log("Contract Creation");
        _owner = msg.sender;

        _token_base = IERC20(token_base_address);
        _token_term = IERC20(token_term_address);
    }

    // Resets all 
    function reset() public onlyOwner {
        // Deleting orders
        for(uint256 i = 0; i <= _order_count; i++) {
            delete _orders[i];
        }
        // Deleting buy prices and buy list
        for(uint256 i = 0; i < _buy_prices.length; i++) {
            delete _buy_list[_buy_prices[i]];
        }
        delete _buy_prices;
        // Deleting sell prices and sell list
        for(uint256 i = 0; i < _sell_prices.length; i++) {
            delete _sell_list[_sell_prices[i]];
        }
        delete _sell_prices;
        // Deleting settlements
        delete _settlements;
    }

    function debug() public view returns (string memory) {
        return _debug;
    }

    function set_base_fee(uint256 fee) public onlyOwner {
        _base_fee = fee;
    }

    function get_base_fee() public view returns (uint256) {
        return _base_fee;
    }

    function last_traded_price() public view returns (uint256) {
        return _last_traded_price;
    }

    function set_term_fee(uint256 fee) public onlyOwner {
        _term_fee = fee;
    }

    function get_term_fee() public view returns (uint256) {
        return _term_fee;
    }
 
    function base_token() public view returns (address) {
        return address(_token_base);
    }

    function term_token() public view returns (address) {
        return address(_token_term);
    }

    function add_participant(address participant) public onlyOwner {
        _participants[participant] = true;
        emit ParticipantAddedEvent(participant);
    }

    function remove_participant(address participant) public onlyOwner {
        _participants[participant] = false;
        emit ParticipantRemovedEvent(participant);
    }

    function is_participant_allowed(address participant) public view returns (bool) {
        return _participants[participant];
    }

    function is_trading_allowed() public view returns (bool) {
        return _trading_allowed;
    }

    function stop_trading() public onlyOwner {
        _trading_allowed = false;
        emit TradingStoppedEvent();
    }

    function start_trading() public onlyOwner {
        _trading_allowed = true;
        emit TradingStartedEvent();
    }

    function best_buy_price() public view returns (uint256) {
        return _buy_prices[0];
    }

    function best_sell_price() public view returns (uint256) {
        return _sell_prices[0];
    }

    // Returns either buy or sell prices - remember those are sorted on insert
    function prices_by_verb(bool is_buy) private view returns (uint256[] storage) {
        if (is_buy) {
            return _buy_prices;
        } else {
            return _sell_prices;
        }
    }

    function buy_prices() public view returns (uint256[] memory)  {
        return _buy_prices;
    }

    function sell_prices() public view returns (uint256[] memory)  {
        return _sell_prices;
    }

    function buy_order_ids(uint256 price) public view returns (uint256[] memory) {
        return _buy_list[price];
    }

    function sell_order_ids(uint256 price) public view returns (uint256[] memory) {
        return _sell_list[price];
    }

    // Returns an order as a n-tuple - Used by the Java CLI to display the order book
    function get_order(uint256 id) public view returns (uint256, address, bool, uint256, uint256) {
        Order storage lo = _orders[id];
        return (lo.id_ext, lo.owner, lo.is_buy, lo.price, lo.size);
    }

    function get_number_of_settlements() public onlyParticipant view returns (uint256)  {
        return _settlements.length;
    }

    // Returns un settlement at given index
    function get_settlement(uint256 index) public onlyParticipant view returns (address adr1, uint256 token1_amount, address token1, address adr2, uint256 token2_amount, address token2, uint256 price) {
        Settlement storage stl = _settlements[index];
        return (stl.adr1, stl.token1_amount, stl.token1, stl.adr2, stl.token2_amount, stl.token2, stl.price);
    }

    // Adds price - sort on insert, increasing for sell, decreasing for buy
    // public for testing - to remove for deployment
    function add_price(uint256 price, bool is_buy) public { 
        uint256[] storage prices = prices_by_verb(is_buy);
        uint index = type(uint).min;
        bool found = false;

        for(uint i = 0; i < prices.length; i++) {
            if (price == prices[i]) {
                return;
            }
            if (!is_buy) {
                if (price < prices[i]) {
                    index = i;
                    found = true;
                    break;
                }
            } else {
                if (price > prices[i]) {
                    index = i;
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            prices.push(price);
        } else {
            uint256[] memory _new_array = new uint[](prices.length + 1);
            for(uint i = 0; i < index; i++) {
                _new_array[i] = prices[i];
            }
            _new_array[index] = price;
            for(uint i = index + 1; i <= prices.length; i++) {
                 _new_array[i] = prices[i - 1];
            }
            if (is_buy) {
                _buy_prices = _new_array;
            } else {
                _sell_prices = _new_array;
            }
        }
    }

    // Returns respectively the best buy and sell price
    function best_price(bool is_buy) public view returns (uint256) {
        uint256 bp = type(uint256).min;
        if (is_buy && _buy_prices.length > 0) {
            bp = _buy_prices[0];
        } else if (!is_buy && _sell_prices.length > 0) {
            bp = _sell_prices[0];
        }
        return bp;
    }

    // Validates a limit order
    function validate_limit_order(uint256 ext_order_id, bool is_buy, uint256 amount, uint256 price) public view {
        validate_amount(amount);
        require(price > 0, "Price must be > 0");
        require(_order_ext_int_mapping[ext_order_id] == 0, "External order id already exists");

        uint256 best_opp_price = best_price(!is_buy);
        if (best_opp_price == type(uint256).min) {
            return;
        }
        if (is_buy) {
             require(price <= best_opp_price, "Crossed buy price > best sell price");
        } else {
            require(price >= best_opp_price, "Crossed sell price < best buy price");
        }
    }

    function validate_market_order(uint256 amount) private pure {
        validate_amount(amount);
    }

    function validate_amount(uint256 amount) private pure {
        require(amount > 0, "Amount must be > 0");
    }

    // Removes prices for which there are no more orders
    function clean_up() private {
        _debug = "clean_up";
       for(uint i = 0; i < _buy_prices.length; i++) {
           uint256 buy_price = _buy_prices[i];
           uint256[] storage buy_list = _buy_list[buy_price];
           if (buy_list.length == 0) {
               delete _buy_list[buy_price];
               delete _buy_prices[i];
           }
       }
       for(uint i = 0; i < _sell_prices.length; i++) {
           uint256 sell_price = _sell_prices[i];
           uint256[] storage sell_list = _sell_list[sell_price];
           if (sell_list.length == 0) {
               delete _sell_list[sell_price];
               delete _sell_prices[i];
           }
       }
   }

    function create_order(address owner, uint256 ext_order_id, bool is_buy, uint256 amount, uint256 price) private returns (Order memory) {
        Order memory order = Order(_order_count, ext_order_id, owner, is_buy, amount, price);
        _order_count = _order_count + 1;
        return order;
    }

    function list_by_verb(bool is_buy) private view returns (mapping(uint256 => uint256[]) storage) {
        if (is_buy) {
            return _buy_list;
        } else {
            return _sell_list;
        }
    }

    function store_order(Order memory order) private {
        // console.log("[SV2] store_order %s %s", order.id_int, order.id_ext);
        _order_ext_int_mapping[order.id_ext] = order.id_int;
        _orders[order.id_int] = order;

        add_price(order.price, order.is_buy);
        mapping(uint256 => uint256[]) storage list = list_by_verb(order.is_buy);
        list[order.price].push(order.id_int);
    }

    function remove_order(uint256 order_id, bool is_buy) private {
        // console.log("[SV2] remove_order %s %s", order_id, is_buy);
        if (is_buy) {
            remove_buy_order(order_id);
        } else {
            remove_sell_order(order_id);
        }
    }

    function remove_buy_order(uint256 order_id) private {
        // console.log("[DBEX] remove_buy_order %s", order_id);
        for(uint i = 0; i < _buy_prices.length; i++) {
           uint256 buy_price = _buy_prices[i];
           uint256[] storage buy_list = _buy_list[buy_price];
           bool found = false;
           for(uint j = 0; j < buy_list.length; j++) {
               if (buy_list[j] == order_id) {
                   for(uint k = i; k < buy_list.length - 1; k++) {
                       buy_list[k] = buy_list[k + 1];
                    }
                    buy_list.pop();
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        } // for
    }

    function remove_sell_order(uint256 order_id) private {
        // console.log("[DBEX] remove_sell_order %s", order_id);
        for(uint i = 0; i < _sell_prices.length; i++) {
           uint256 sell_price = _sell_prices[i];
           uint256[] storage sell_list = _sell_list[sell_price];
           bool found = false;
           for(uint j = 0; j < sell_list.length; j++) {
               if (sell_list[j] == order_id) {
                   for(uint k = i; k < sell_list.length - 1; k++) {
                       sell_list[k] = sell_list[k + 1];
                    }
                    sell_list.pop();
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        } // for
    }

    function place_limit_order(
        uint256 ext_order_id, 
        bool is_buy, 
        uint256 amount, 
        uint256 price) public tradingAllowed {
            
        _debug = "validating limit order";
        validate_limit_order(ext_order_id, is_buy, amount, price);
        _debug = "validated limit order";

        // Retrieves the list of prices to internal order ids
        mapping(uint256 => uint256[]) storage opp_order_list = list_by_verb(!is_buy);

        _debug = "creating memory limit order";
        Order memory order = create_order(msg.sender, ext_order_id, is_buy, amount, price);
        _debug = "created limit order";

        if (opp_order_list[price].length == 0 || best_price(!is_buy) != price) { 
            // No opposite order at that price, we can just place it or
            // There are opposite orders but not at that price
            // Crosses are handled by the validate method
            // console.log("[DBEX] No opposite order and/or at that pice, placing order");
            _debug = "storing limit order (no opposite order)";
            store_order(order);
            _debug = "stored limit order. emitting event  (no opposite order)";
            emit OrderPlacedEvent(order);
            _debug = "emitted OrderPlacedEvent";
            return;
        }

        _debug = "matched scenario";

        // We are in a matched scenario - we need to get the order ids for the price
        _last_traded_price = price;
        uint256[] storage matched_orders_ids = opp_order_list[price];
        uint256[] memory moids =  new uint256[](matched_orders_ids.length);
        for(uint i = 0; i < matched_orders_ids.length; i++) {
            moids[i] = matched_orders_ids[i];
        }
        // console.log("[DBEX] Match scenario. Nb matched orders: %s", moids.length);

        uint256 size_left = amount;
        for(uint i = 0; i < moids.length && size_left > 0; i++) {
            Order storage matched_order = _orders[moids[i]];
            require(msg.sender != matched_order.owner, "Cannot match own order");

            if (size_left >= matched_order.size) {
                // console.log("[DBEX] %s >= %s", size_left,  matched_order.size);
                remove_order(matched_order.id_int, matched_order.is_buy);
                _debug = "matched scenario. emitting OrderUpdatedEvent";
                emit OrderUpdatedEvent(matched_order);
                size_left = size_left - matched_order.size;
                // console.log("[DBEX] new size left %s", size_left);
            } else {
                // console.log("[DBEX] size_left = 0");
                Order memory updated_order = Order(matched_order.id_int, matched_order.id_ext, matched_order.owner, matched_order.is_buy, matched_order.size - size_left, matched_order.price);
                size_left = 0;
                _orders[matched_order.id_int] = updated_order;
                _debug = "matched scenario. size left. emitting OrderUpdatedEvent";
                emit OrderUpdatedEvent(updated_order);
            }
            process_trade(matched_order.owner, order.owner, is_buy, matched_order.size, price);
        } // For each matched order

        if (size_left > 0) {
            // console.log("[SV2] size_left > 0. Creating and storing new order");
            Order memory new_order = create_order(msg.sender, ext_order_id, is_buy, size_left, price);
            store_order(new_order);
            _debug = "matched scenario. size left. emitting OrderPlacedEvent";
            emit OrderPlacedEvent(new_order);
        }

        clean_up();
    }

    // Spefically to keep orders we have matchd
    // uint256[] private _matched_order_ids;
    function place_market_order(
        bool is_buy, 
        uint256 amount) public tradingAllowed {
        validate_market_order(amount);
        // console.log("place_market_order for amount %s ...", amount);
        
        uint256[] storage other_prices = prices_by_verb(!is_buy);
        mapping(uint256 => uint256[]) storage opp_order_list = list_by_verb(!is_buy);

        uint256 amount_left = amount;
        bool done = false;
        
        for(uint i = 0; i < other_prices.length; i++) {
            uint256[] storage other_order_ids = opp_order_list[other_prices[i]];
            
            for(uint j = 0; j < other_order_ids.length; j++) {
                Order storage other_order = _orders[other_order_ids[j]];

                if (amount_left <= other_order.size) {
                    // console.log("Market order -> Trade with %s for size %s cumul", other_order.id_int, other_order.size);
                    process_trade(other_order.owner, msg.sender, is_buy, amount_left, other_order.price);
                    // console.log("1/ -> Gen Trade for amount %s", amount_left);
                    if (amount_left == other_order.size) {
                        // console.log("2/   -> delete order %s", other_order.id_int);
                        remove_order(other_order.id_int, other_order.is_buy);
                    } else {
                        // console.log("3/   -> update order %s with new size %s", other_order.id_int, other_order.size - amount_left);
                        Order memory updated_order = Order(other_order.id_int, other_order.id_ext, other_order.owner, other_order.is_buy, other_order.size - amount_left, other_order.price);
                        _orders[updated_order.id_int] = updated_order;
                    }
                    done = true;
                } else {
                    amount_left = amount_left - other_order.size;
                    // console.log("4a/ -> delete order %s amount_left %s", other_order.id_int, amount_left);
                    // console.log("4a/ -> Gen Trade for amount %s", other_order.size);
                    process_trade(other_order.owner, msg.sender, is_buy, other_order.size, other_order.price);
                    remove_order(other_order.id_int, other_order.is_buy);
                }
            }
            if (done) {
                break;
            }
        }
    }

    function process_trade(address matched_owner, address order_owner, bool is_buy, uint256 size, uint256 price) private {
        // console.log("[DBEX] process_trade matched owner %s order owner %s for size @ price", matched_owner, order_owner);
        // console.logUint(size);
        // console.logUint(price);
        
        uint256 amount_to_transfer = size * price;
        if (is_buy) {
            // console.log("[DBEX] BuyO %s transfers %s token_1 to %s", matched_owner, size, order_owner);
            // console.log("[DBEX] BuyO %s transfers %s token_2 to %s", order_owner, amount_to_transfer, matched_owner);
            emit SettlementInstruction(matched_owner, size, address(_token_base), order_owner, amount_to_transfer, address(_token_term), price);
            _settlements.push(Settlement(matched_owner, size, address(_token_base), order_owner, amount_to_transfer, address(_token_term), price));
           
            require(_token_base.allowance(matched_owner, address(this)) >= size, "{Buy} Not enough funds for settlement for matched_owner");
            require(_token_term.allowance(order_owner, address(this)) >= amount_to_transfer, "{Buy} Not enough funds for order_owner");
            
            bool sent = _token_base.transferFrom(matched_owner, order_owner, size);
            require(sent, "Transfer 1 failed");
            sent = _token_term.transferFrom(order_owner, matched_owner, amount_to_transfer);
            require(sent, "Transfer 2 failed");
        } else {
            emit SettlementInstruction(matched_owner, amount_to_transfer, address(_token_term), order_owner, size, address(_token_base), price);
            _settlements.push(Settlement(matched_owner, amount_to_transfer, address(_token_term), order_owner, size, address(_token_base), price));
        
            require(_token_term.allowance(matched_owner, address(this)) >= amount_to_transfer, "{Buy} Not enough funds for settlement from matched_owner");
            require(_token_base.allowance(order_owner, address(this)) >= size, "{Buy} Not enough funds for settlement from order_owner");
            
            bool sent = _token_term.transferFrom(matched_owner, order_owner, amount_to_transfer);
            require(sent, "Transfer 1 failed");
            sent = _token_base.transferFrom(order_owner, matched_owner, size);
            require(sent, "Transfer 2 failed");
        }
    }

    function print_clob() public view {
        // console.log("> BEGIN CLOB <");
        // console.log(" Buy Orders");
        for(uint i = 0; i < _buy_prices.length; i++) {
            uint256[] storage order_ids = _buy_list[_buy_prices[i]];
            if (order_ids.length > 0)
                // console.log("  For price %s", _buy_prices[i]);
            for(uint j = 0; j < order_ids.length; j++) {
                Order storage lo = _orders[order_ids[j]];
                if (lo.price > 0 && lo.size > 0) {
                    //  console.logUint(lo.id_ext);
                    // console.log("    Order %s %s @ %s", lo.is_buy, lo.size, lo.price);
                }
            }
        }
        // console.log(" Sell Orders");
        for(uint i = 0; i < _sell_prices.length; i++) {
            uint256[] storage order_ids = _sell_list[_sell_prices[i]];
            if (order_ids.length > 0)
                // console.log("  For price %s", _sell_prices[i]);
            for(uint j = 0; j < order_ids.length; j++) {
                Order storage lo = _orders[order_ids[j]];
                if (lo.price > 0 && lo.size > 0) {
                    // console.logUint(lo.id_ext);
                    // console.log("    Order %s %s @ %s", lo.is_buy, lo.size, lo.price);
                }
            }
        }
        // console.log("> END ---- <");
    }
}