import ape
import pytest


@pytest.fixture(scope="session")
def alice(accounts):
    return accounts[0]


@pytest.fixture(scope="session")
def unauthorised_account(accounts):
    return accounts[1]


@pytest.fixture(scope="session")
def random_address(accounts):
    return accounts[2]


@pytest.fixture(scope="module")
def owner(accounts):
    address_provider = ape.project.AddressProvider.at("0x0000000022D53366457F9d5E68Ec105046FC4383")
    return accounts[address_provider.admin()]
