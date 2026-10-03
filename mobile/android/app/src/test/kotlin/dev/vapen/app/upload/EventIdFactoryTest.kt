package dev.vapen.app.upload

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class EventIdFactoryTest {
    @Test
    fun puffId_isDeterministicForDeviceIndex() {
        val a = EventIdFactory.puffId("abc", 42L, Instant.parse("2026-10-03T10:00:00Z"))
        val b = EventIdFactory.puffId("abc", 42L, Instant.parse("2026-10-03T11:00:00Z"))
        assertEquals(a, b)
    }
}
