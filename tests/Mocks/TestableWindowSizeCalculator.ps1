class TestableWindowSizeCalculator : WindowSizeCalculator {
    [object] $MockRawUI
    
    TestableWindowSizeCalculator() {
    }
    
    SetMockRawUI([object]$mock) {
        $this.MockRawUI = $mock
    }
    
    [object] GetRawUI() {
        return $this.MockRawUI
    }
}
