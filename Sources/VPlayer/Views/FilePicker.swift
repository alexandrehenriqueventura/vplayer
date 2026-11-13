import AppKit
import AVFoundation
import UniformTypeIdentifiers

enum FilePicker {
    @MainActor
    static func openAudio(player: PlayerViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.prompt = "Adicionar"
        if panel.runModal() == .OK {
            player.addFiles(urls: panel.urls)
        }
    }

    @MainActor
    static func openPlaylist(player: PlayerViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Abrir"
        if panel.runModal() == .OK, let url = panel.url {
            player.importPlaylist(from: url)
        }
    }

    @MainActor
    static func exportPlaylist(player: PlayerViewModel) {
        guard !player.tracks.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "vplayer.m3u"
        panel.prompt = "Salvar"
        if panel.runModal() == .OK, let url = panel.url {
            player.exportPlaylist(to: url)
        }
    }
}
