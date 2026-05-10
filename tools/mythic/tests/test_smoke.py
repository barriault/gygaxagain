def test_mythic_imports():
    import mythic
    assert mythic is not None


def test_fate_chart_module_exists():
    from mythic import fate_chart
    assert hasattr(fate_chart, "FATE_CHART")
