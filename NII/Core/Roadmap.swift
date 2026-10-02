//
//  Roadmap.swift
//  NII App
//
//  "90 days to a large-scale result" — the NII poster, column by column:
//  0 = Point A (day 1), then weeks 1–12.
//

import Foundation

enum Roadmap {
    static let columns: [(week: Int, tasks: [String])] = [
        (0, ["Запустить полноценный сайт НИИ (направления, команда, проекты, публикации, лаборатории)",
             "Сделать большую брошюру НИИ на русском и английском языках",
             "Собрать все научные работы в единую Research Library"]),
        (1, ["Разделить исследования по направлениям (AI, construction, water, assistive tech, education и др.)",
             "Выделить 10 флагманских исследований",
             "Создать Research Roadmap на 3 года"]),
        (2, ["Создать 5–10 собственных лабораторий / направлений",
             "Сформировать International Scientific Board",
             "Привлечь доп. PhD, докторов наук, магистров в команду и закрепить KPI"]),
        (3, ["Создать реестр публикаций (Scopus / WoS / ККСОН)",
             "Создать реестр первых MOU и партнёров",
             "Запустить план 20–30 статей и серию монографий"]),
        (4, ["Создать реестр публикаций и научных семинаров",
             "Создать реестр патентов и заявок",
             "Подготовить план отдела Commercialization НИИ"]),
        (5, ["Запустить ежемесячные научные семинары",
             "Подготовить первую международную конференцию НИИ (100–200 чел.)",
             "Запустить конкурс «100 Young Researchers»"]),
        (6, ["Создать Research Demo Day и выставку «Science to Prototype»",
             "Подписать первые 5 MOU с зарубежными университетами и центрами",
             "Запустить Research Internship для школьников, студентов, магистров"]),
        (7, ["Интегрировать институт с MASHSTROY, ARAI AI, KKSU, AIKEN, ATA MURA, EPISTOME",
             "Подать заявки на ключевые гранты",
             "Создать Grant Office и отдел Commercialization & Technology Transfer"]),
        (8, ["Разработать проект Conference & Research Center (зал на 100–200 чел., Demo Hall, лаборатории)",
             "Запустить библиотеку и подписки на научные базы; запуск издательской линии EPISTOME",
             "Организовать международный Scientific Advisory Day"]),
        (9, ["Подготовить 3–5 прототипов по флагманским разработкам",
             "Довести количество партнёрств до 10+",
             "Выпустить первый NII Research Report"]),
        (10, ["Запустить международную конференцию для молодых исследователей",
              "Получить первые корпоративные R&D-контракты / пилоты",
              "Привлечь 20 корпоративных и научных партнёров"]),
        (11, ["Расширить Demo Hall и подготовить площадку выставки с прототипами",
              "Подать новые патентные заявки по ключевым разработкам",
              "Начать совместные исследовательские проекты с университетами США, Европы и Азии"]),
        (12, ["Закрепить статус НИИ как международного центра Inclusive Engineering",
              "Подготовить масштабированную конференцию до 300–500+ человек",
              "Переход к большому этапу внедрения и международному росту"]),
    ]

    static let pointB = ["Сайт и Research Library", "10 флагманских исследований", "Международные партнёрства",
                         "Первая конференция и Demo Day", "Гранты и пилоты", "Патентные заявки",
                         "Прототипы и лаборатории", "Команда и система", "Международное признание"]

    static func title(_ week: Int) -> String { week == 0 ? "Точка А" : "Неделя \(week)" }
    static func days(_ week: Int) -> String { week == 0 ? "День 1" : "Дни \((week - 1) * 7 + 1)–\(week == 12 ? 90 : week * 7)" }

    /// Due day of a column counted from day 1: Point A → day 1, week N → day N*7, week 12 → day 90
    static func dueDay(_ week: Int) -> Int { week == 0 ? 1 : (week == 12 ? 90 : week * 7) }

    static func dueDate(week: Int, start: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NIIDate.timeZone
        let date = calendar.date(byAdding: .day, value: dueDay(week) - 1, to: start) ?? start
        return NIIDate.day(date)
    }
}
