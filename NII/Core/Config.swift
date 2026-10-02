//
//  Config.swift
//  NII App
//
//  Supabase project (Project Settings → API Keys). The publishable/anon key is public by
//  design: access to data is limited by the RLS rules in backend/schema.sql.
//  Never put the secret service_role key into the app.
//

import Foundation

enum NIIConfig {
    // Same Supabase project as KKSU Online: NII tables are separate (all start with nii_).
    // To use a separate project, replace both values (see README).
    static let supabaseURL = "https://vllechyeunbtozhubuud.supabase.co"
    static let supabaseKey = "sb_publishable_ThNRdPI2yoG1rQxLAiwusg_CmxF8Y7Y"

    /// Auto-renewable subscription in App Store Connect (and in NII.storekit for testing).
    static let proProductID = "kz.nii.app.pro.monthly"

    /// Required on the subscription screen by App Store rules
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://github.com/aiganymaset002-arch/nii-app/blob/main/PRIVACY.md")!

    /// Merch is a physical product: it is paid by bank transfer, not through the App Store.
    static let merchPaymentInfo = """
    Kaspi (Kaspi Gold / перевод по номеру): +7 771 473 18 52
    Любой банк Казахстана — перевод по номеру телефона: +7 771 473 18 52
    В комментарии укажите номер заказа. После оплаты организатор подтвердит заказ.
    """

    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR-PROJECT") && !supabaseKey.hasPrefix("YOUR-")
    }
}
