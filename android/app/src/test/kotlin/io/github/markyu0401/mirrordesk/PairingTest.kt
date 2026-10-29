package io.github.markyu0401.mirrordesk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PairingTest {
    @Test
    fun parsesValidUri() {
        val p = Pairing.parse("mirrordesk://pair?v=1&host=192.168.1.10&port=54321&token=abc")
        assertEquals("192.168.1.10", p?.host)
        assertEquals(54321, p?.port)
        assertEquals("abc", p?.token)
        assertEquals(1, p?.version)
    }

    @Test
    fun rejectsInvalidUri() {
        assertNull(Pairing.parse("https://example.com"))
        assertNull(Pairing.parse("mirrordesk://pair?host=x"))
    }
}
