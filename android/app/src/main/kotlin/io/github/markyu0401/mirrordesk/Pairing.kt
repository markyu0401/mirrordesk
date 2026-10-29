package io.github.markyu0401.mirrordesk

data class Pairing(
    val host: String,
    val port: Int,
    val token: String,
    val version: Int = 1
) {
    companion object {
        fun parse(uri: String): Pairing? {
            val prefix = "mirrordesk://pair?"
            if (!uri.startsWith(prefix)) return null
            val params = uri.removePrefix(prefix)
                .split("&")
                .mapNotNull {
                    val parts = it.split("=", limit = 2)
                    if (parts.size == 2) parts[0] to parts[1] else null
                }
                .toMap()
            val host = params["host"] ?: return null
            val port = params["port"]?.toIntOrNull() ?: return null
            val token = params["token"] ?: return null
            val version = params["v"]?.toIntOrNull() ?: 1
            return Pairing(host, port, token, version)
        }
    }
}
