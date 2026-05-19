import SwiftUI

struct SettingsView: View {
    @AppStorage("kubik.haptics") private var haptics = true
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Настройки")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .frame(width: 38, height: 38)
                                .background(Theme.panel, in: Circle())
                        }
                    }

                    Toggle(isOn: $haptics) {
                        Text("Вибрация")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .tint(Theme.accent)
                    .padding(14)
                    .background(Theme.panel,
                                in: RoundedRectangle(cornerRadius: 14))

                    block(title: "Блоки", body:
                        "Перетаскивай фигуры из нижнего ряда на поле 8x8. "
                        + "Когда ряд или столбец заполнен целиком, он сгорает "
                        + "и даёт очки. Классика идёт пока есть ходы. На время "
                        + "это 3 минуты на максимум очков. Зен без проигрыша: "
                        + "при тупике поле само освобождается.")

                    block(title: "Дурак", body:
                        "Игра один на один с ботом, колода 36 карт. Масть "
                        + "козыря показана сверху. Атакуя, кладёшь карту. "
                        + "Защищаясь, бей карту старшей той же масти или "
                        + "козырем (подсвечена та, что надо отбить). Можно "
                        + "подкинуть карты того же номинала, что уже на столе. "
                        + "Не можешь отбиться нажми Взять. Отбил всё нажми "
                        + "Бито. Кто остался с картами, когда колода кончилась, "
                        + "тот дурак.")

                    Text("Kubik · без интернета и аккаунтов")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                }
                .padding(20)
            }
        }
    }

    private func block(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
