# @version 0.3.3
"""
@title Curve Registry Handler for v2 Crypto Registry
@license MIT
"""

# ---- interfaces --- #
interface AddressProvider:
    def get_address(_id: uint256) -> address: view


interface BaseRegistry:
    def find_pool_for_coins(_from: address, _to: address, i: uint256 = 0) -> address: view
    def get_admin_balances(_pool: address) -> uint256[MAX_COINS]: view
    def get_balances(_pool: address) -> uint256[MAX_COINS]: view
    def get_coins(_pool: address) -> address[MAX_COINS]: view
    def get_coin_indices(_pool: address, _from: address, _to: address) -> uint256[2]: view
    def get_decimals(_pool: address) -> uint256[MAX_COINS]: view
    def get_fees(_pool: address) -> uint256[4]: view
    def get_gauges(_pool: address) -> (address[10], int128[10]): view
    def get_lp_token(_pool: address) -> address: view
    def get_n_coins(_pool: address) -> uint256: view
    def get_pool_from_lp_token(_lp_token: address) -> address: view
    def get_pool_name(_pool: address) -> String[64]: view
    def get_virtual_price_from_lp_token(_token: address) -> uint256: view
    def pool_count() -> uint256: view
    def pool_list(pool_id: uint256) -> address: view


interface CurvePool:
    def adjustment_step() -> uint256: view
    def admin_fee() -> uint256: view
    def allowed_extra_profit() -> uint256: view
    def A() -> uint256: view
    def D() -> uint256: view
    def fee() -> uint256: view
    def fee_gamma() -> uint256: view
    def gamma() -> uint256: view
    def get_virtual_price() -> uint256: view
    def ma_half_time() -> uint256: view
    def mid_fee() -> uint256: view
    def out_fee() -> uint256: view
    def virtual_price() -> uint256: view
    def xcp_profit() -> uint256: view
    def xcp_profit_a() -> uint256: view


interface ERC20:
    def name() -> String[64]: view
    def balanceOf(_addr: address) -> uint256: view
    def totalSupply() -> uint256: view


interface MetaRegistry:
    def registry_length() -> uint256: view


# ---- constants ---- #
MAX_COINS: constant(uint256) = 8

# ---- storage variables ---- #
base_registry: public(BaseRegistry)
registry_id: uint256
registry_index: uint256


# ---- constructor ---- #
@external
def __init__(_metaregistry: address, _id: uint256, address_provider: address):
    self.base_registry = BaseRegistry(AddressProvider(address_provider).get_address(_id))
    self.registry_id = _id
    self.registry_index = MetaRegistry(_metaregistry).registry_length()


# ---- internal methods ---- #
@internal
@view
def _get_balances(_pool: address) -> uint256[MAX_COINS]:
    return self.base_registry.get_balances(_pool)


@internal
@view
def _get_coins(_pool: address) -> address[MAX_COINS]:
    return self.base_registry.get_coins(_pool)


@internal
@view
def _get_lp_token(_pool: address) -> address:
    return self.base_registry.get_lp_token(_pool)


@internal
@view
def _get_n_coins(_pool: address) -> uint256:
    return self.base_registry.get_n_coins(_pool)


# ---- view methods (API) of the contract ---- #
@external
@view
def find_pool_for_coins(_from: address, _to: address, i: uint256 = 0) -> address:
    return self.base_registry.find_pool_for_coins(_from, _to, i)


@external
@view
def get_admin_balances(_pool: address) -> uint256[MAX_COINS]:
    """
    @dev Cryptoswap pools do not store admin fees in the form of
         admin token balances. Instead, the admin fees are computed
         at the time of claim iff sufficient profits have been made.
         These fees are allocated to the admin by minting LP tokens
         (dilution). The logic to calculate fees are derived from
         cryptopool._claim_admin_fees() method.
    """
    xcp_profit: uint256 = CurvePool(_pool).xcp_profit()
    xcp_profit_a: uint256 = CurvePool(_pool).xcp_profit_a()
    admin_fee: uint256 = CurvePool(_pool).admin_fee()
    admin_balances: uint256[MAX_COINS] = empty(uint256[MAX_COINS])

    # admin balances are non zero if pool has made more than allowed profits:
    if xcp_profit > xcp_profit_a:

        # calculate admin fees in lp token amounts:
        fees: uint256 = (xcp_profit - xcp_profit_a) * admin_fee / (2 * 10**10)
        if fees > 0:
            vprice: uint256 = CurvePool(_pool).virtual_price()
            lp_token: address = self._get_lp_token(_pool)
            frac: uint256 = vprice * 10**18 / (vprice - fees) - 10**18

            # the total supply of lp token is current supply + claimable:
            lp_token_total_supply: uint256 = ERC20(lp_token).totalSupply()
            d_supply: uint256 = lp_token_total_supply * frac / 10**18
            lp_token_total_supply += d_supply
            admin_lp_frac: uint256 = d_supply * 10 ** 18 / lp_token_total_supply

            # get admin balances in individual assets:
            reserves: uint256[MAX_COINS] = self._get_balances(_pool)
            for i in range(MAX_COINS):
                admin_balances[i] = admin_lp_frac * reserves[i] / 10 ** 18

    return admin_balances


@external
@view
def get_balances(_pool: address) -> uint256[MAX_COINS]:
    return self._get_balances(_pool)


@external
@view
def get_base_pool(_pool: address) -> address:
    return ZERO_ADDRESS


@view
@external
def get_coin_indices(_pool: address, _from: address, _to: address) -> (int128, int128, bool):
    indices: uint256[2] = self.base_registry.get_coin_indices(_pool, _from, _to)
    return convert(indices[0], int128), convert(indices[1], int128), False


@external
@view
def get_coins(_pool: address) -> address[MAX_COINS]:
    return self._get_coins(_pool)


@external
@view
def get_decimals(_pool: address) -> uint256[MAX_COINS]:
    return self.base_registry.get_decimals(_pool)


@external
@view
def get_fees(_pool: address) -> uint256[10]:
    fees: uint256[10] = empty(uint256[10])
    pool_fees: uint256[4] = self.base_registry.get_fees(_pool)
    for i in range(4):
        fees[i] = pool_fees[i]
    return fees


@external
@view
def get_gauges(_pool: address) -> (address[10], int128[10]):
    return self.base_registry.get_gauges(_pool)


@external
@view
def get_lp_token(_pool: address) -> address:
    return self._get_lp_token(_pool)


@external
@view
def get_n_coins(_pool: address) -> uint256:
    return self._get_n_coins(_pool)


@external
@view
def get_n_underlying_coins(_pool: address) -> uint256:
    return self._get_n_coins(_pool)


@external
@view
def get_pool_asset_type(_pool: address) -> uint256:
    """
    review: this can just be a public constant so it has a
            getter auto-generated by the compiler.
    """
    return 4


@external
@view
def get_pool_from_lp_token(_lp_token: address) -> address:
    return self.base_registry.get_pool_from_lp_token(_lp_token)


@external
@view
def get_pool_name(_pool: address) -> String[64]:
    return self.base_registry.get_pool_name(_pool)


@external
@view
def get_pool_params(_pool: address) -> uint256[20]:
    """
    @notice returns pool params given a cryptopool address
    @dev contains all settable parameter that alter the pool's performance
    @dev only applicable for cryptopools
    @param _pool Address of the pool for which data is being queried.
    """

    pool_params: uint256[20] = empty(uint256[20])
    pool_params[0] = CurvePool(_pool).A()
    pool_params[1] = CurvePool(_pool).D()
    pool_params[2] = CurvePool(_pool).gamma()
    pool_params[3] = CurvePool(_pool).allowed_extra_profit()
    pool_params[4] = CurvePool(_pool).fee_gamma()
    pool_params[5] = CurvePool(_pool).adjustment_step()
    pool_params[6] = CurvePool(_pool).ma_half_time()
    return pool_params


@external
@view
def get_underlying_balances(_pool: address) -> uint256[MAX_COINS]:
    return self._get_balances(_pool)


@external
@view
def get_underlying_coins(_pool: address) -> address[MAX_COINS]:
    return self._get_coins(_pool)


@external
@view
def get_underlying_decimals(_pool: address) -> uint256[MAX_COINS]:
    return self.base_registry.get_decimals(_pool)


@external
@view
def get_virtual_price_from_lp_token(_token: address) -> uint256:
    return self.base_registry.get_virtual_price_from_lp_token(_token)


@external
@view
def is_meta(_pool: address) -> bool:
    return False


@external
@view
def is_registered(_pool: address) -> bool:
    """
    @notice Check if a pool belongs to the registry using get_n_coins
    @param _pool The address of the pool
    @return A bool corresponding to whether the pool belongs or not
    """
    return self.base_registry.get_n_coins(_pool) > 0


@external
@view
def pool_count() -> uint256:
    return self.base_registry.pool_count()


@external
@view
def pool_list(_index: uint256) -> address:
    return self.base_registry.pool_list(_index)
