package com.louvorja.louvorja_piano_mobile

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LiturgyTimelineTest {
    private fun item(name: String, start: String?, end: String?) =
        LiturgyTimeline.Item(name, start, end)

    @Test fun `current item exposes exact interval remaining and progress`() {
        val timeline = LiturgyTimeline.at(
            listOf(item("Louvor", "09:00", "09:30")),
            hour = 9,
            minute = 15,
        )
        val current = timeline.current!!
        assertEquals("Louvor", current.name)
        assertEquals("09:00–09:30", current.interval)
        assertEquals(15, current.minutesRemaining)
        assertEquals(50, current.progressPercent)
    }

    @Test fun `sorts timed items and leaves untimed last`() {
        val timeline = LiturgyTimeline.at(
            listOf(item("Sem hora", null, null), item("Sermão", "10:00", "10:30"), item("Louvor", "09:00", "09:30")),
            hour = 8, minute = 50,
        )
        assertEquals(listOf("Louvor", "Sermão", "Sem hora"), timeline.items.map { it.name })
        assertEquals("Louvor", timeline.next!!.name)
    }

    @Test fun `invalid or inverted intervals are never current`() {
        val timeline = LiturgyTimeline.at(
            listOf(item("Ruim", "10:30", "10:00"), item("Texto", "aa:bb", "11:00")),
            hour = 10, minute = 15,
        )
        assertEquals(null, timeline.current)
        assertTrue(timeline.items.all { it.startMinute == null })
    }
}
