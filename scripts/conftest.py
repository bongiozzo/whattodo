"""Pytest configuration for shorter test output."""

def pytest_itemcollected(item):
    """Customize test node IDs for shorter output."""
    # Extract just the test name and remove 'test_' prefix
    test_name = item.originalname or item.name
    if test_name.startswith("test_"):
        test_name = test_name[5:]  # Remove 'test_' prefix
    item._nodeid = test_name
