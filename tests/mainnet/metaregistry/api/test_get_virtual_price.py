import ape
import pytest

# ---- sanity checks since vprice getters can revert for specific pools states ----


def _check_pool_has_no_liquidity(metaregistry, pool, pool_balances, lp_token):

    # skip if pool has little to no liquidity, since vprice queries will most likely bork:
    if sum(pool_balances) == 0:

        with ape.reverts():
            metaregistry.get_virtual_price_from_lp_token(lp_token)

        pytest.skip(f"empty pool: {pool}")

    elif sum(pool_balances) < 100:  # tiny pool
        with ape.reverts():
            metaregistry.get_virtual_price_from_lp_token(lp_token)

        pytest.skip(f"tiny pool: {pool}")


def _check_skem_tokens_with_weird_decimals(
    metaregistry, pool, lp_token, pool_balances, coins, coin_decimals
):

    # check if pool balances after accounting for decimals is legible.
    # some scam tokens can have weird token properties (e.g. ELONX)
    pool_balances_float = []
    for i in range(len(pool_balances)):

        if coins[i] == ape.utils.ZERO_ADDRESS:
            break

        pool_balances_float.append(pool_balances[i] / 10 ** coin_decimals[i])

        if (
            coin_decimals[i] == 0
            and ape.project.ERC20.at(metaregistry.get_coins(pool)[0]).decimals() == 0
        ):
            with ape.reverts():
                metaregistry.get_virtual_price_from_lp_token(lp_token)
            pytest.skip(f"skem token {coins[i]} in pool {pool} with zero decimals")

    return pool_balances_float


def _check_pool_is_depegged(
    metaregistry, pool, pool_balances, pool_balances_float, coin_decimals, lp_token
):

    for i in range(len(pool_balances)):
        # check if pool balances are skewed: vprice calc will bork if one of the coin
        # balances is close to zero.
        if (
            max(pool_balances_float) - min(pool_balances_float)
            == pytest.approx(max(pool_balances_float))
            and min(pool_balances_float) < 1
        ):
            with ape.reverts():
                metaregistry.get_virtual_price_from_lp_token(lp_token)

            pytest.skip(
                f"skewed pool: {pool} as num coins (decimals divided) at index {i} is "
                f"{pool_balances[i] / 10 ** coin_decimals[i]}"
            )


def pre_test_checks(metaregistry, pool):

    pool_balances = metaregistry.get_balances(pool)
    lp_token = metaregistry.get_lp_token(pool)

    _check_pool_has_no_liquidity(metaregistry, pool, pool_balances, lp_token)

    coin_decimals = metaregistry.get_decimals(pool)
    coins = metaregistry.get_coins(pool)

    pool_balances_float = _check_skem_tokens_with_weird_decimals(
        metaregistry, pool, lp_token, pool_balances, coins, coin_decimals
    )

    _check_pool_is_depegged(
        metaregistry, pool, pool_balances, pool_balances_float, coin_decimals, lp_token
    )

    return lp_token


# ----  tests ----


def test_stable_registry_pools(populated_metaregistry, stable_registry_pool, stable_registry):

    # if checks fail, pytest skips, else lp_token is returned:
    lp_token = pre_test_checks(populated_metaregistry, stable_registry_pool)
    actual_output = stable_registry.get_virtual_price_from_lp_token(lp_token)
    metaregistry_output = populated_metaregistry.get_virtual_price_from_lp_token(lp_token)
    assert actual_output == metaregistry_output


def test_stable_factory_pools(populated_metaregistry, stable_factory_pool, curve_pool):

    # if checks fail, pytest skips, else lp_token is returned:
    lp_token = pre_test_checks(populated_metaregistry, stable_factory_pool)

    try:
        actual_output = curve_pool(stable_factory_pool).get_virtual_price()
        metaregistry_output = populated_metaregistry.get_virtual_price_from_lp_token(lp_token)
        assert actual_output == metaregistry_output
    except ape.exceptions.ContractLogicError:
        with ape.reverts():
            populated_metaregistry.get_virtual_price_from_lp_token(lp_token)


def test_crypto_registry_pools(populated_metaregistry, crypto_registry_pool, crypto_registry):

    # if checks fail, pytest skips, else lp_token is returned:
    lp_token = pre_test_checks(populated_metaregistry, crypto_registry_pool)
    actual_output = crypto_registry.get_virtual_price_from_lp_token(lp_token)
    metaregistry_output = populated_metaregistry.get_virtual_price_from_lp_token(lp_token)
    assert actual_output == metaregistry_output


def test_crypto_factory_pools(populated_metaregistry, crypto_factory_pool, curve_pool):

    # if checks fail, pytest skips, else lp_token is returned:
    lp_token = pre_test_checks(populated_metaregistry, crypto_factory_pool)
    actual_output = curve_pool(crypto_factory_pool).get_virtual_price()

    metaregistry_output = populated_metaregistry.get_virtual_price_from_lp_token(lp_token)
    assert actual_output == metaregistry_output
