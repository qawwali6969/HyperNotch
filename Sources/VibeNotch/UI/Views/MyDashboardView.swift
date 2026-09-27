import SwiftUI

struct MyDashboardView: View {
    @ObservedObject var manager = DashboardManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var isEditingConfig = false
    @State private var isAddingSite = false
    
    // Config fields
    @State private var editName = ""
    @State private var editBaseUrl = ""
    @State private var editLoginPath = ""
    @State private var editApiPath = ""
    
    // New site fields
    @State private var newName = ""
    @State private var newBaseUrl = ""
    @State private var newLoginPath = "/login"
    @State private var newApiPath = "/api/admin/stats"
    
    var currentProfileName: String {
        manager.profiles.first(where: { $0.id == manager.currentProfileId })?.name ?? loc("Dashboard", "Дашборд")
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                // Profile Switcher Menu
                Menu {
                    ForEach(manager.profiles) { p in
                        Button(action: {
                            manager.selectProfile(id: p.id)
                        }) {
                            HStack {
                                Text(p.name)
                                if p.id == manager.currentProfileId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button(action: {
                        newName = ""
                        newBaseUrl = ""
                        isAddingSite = true
                    }) {
                        Label(loc("Add new service...", "Добавить новый сервис..."), systemImage: "plus.circle")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(currentProfileName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                }
                .menuStyle(.borderlessButton)
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.isOnline ? Color.green : (manager.isLoggedIn ? Color.orange : Color.secondary))
                        .frame(width: 6, height: 6)
                    
                    Text(manager.isOnline ? "Live API" : (manager.isLoggedIn ? loc("Session Active", "Сессия активна") : loc("Not Logged In", "Вход не выполнен")))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(manager.isOnline ? .green : (manager.isLoggedIn ? .orange : .secondary))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
                
                Spacer()
                
                if let updated = manager.lastUpdated {
                    Text(updated, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                
                // Config Toggle Button
                Button(action: {
                    if !isEditingConfig {
                        editName = currentProfileName
                        editBaseUrl = manager.baseUrl
                        editLoginPath = manager.loginPath
                        editApiPath = manager.statsApiPath
                    }
                    withAnimation(.spring) {
                        isEditingConfig.toggle()
                        isAddingSite = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isEditingConfig ? "xmark" : "gearshape")
                        Text(isEditingConfig ? loc("Close", "Закрыть") : loc("Settings", "Настройки"))
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                // Refresh Button
                Button(action: {
                    Task {
                        await manager.fetchStats()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                        .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // Add Site Dialog
            if isAddingSite {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("ADD NEW SERVICE / WEBSITE", "ДОБАВЛЕНИЕ НОВОГО СЕРВИСА / САЙТА"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField(loc("Name (e.g. My SaaS)", "Название (например: Мой SaaS)"), text: $newName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10))
                            .padding(5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        TextField("https://mysite.com", text: $newBaseUrl)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        TextField("/login", text: $newLoginPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 80)
                        
                        TextField("/api/stats", text: $newApiPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 100)
                        
                        VibeInteractiveHoverButton(text: loc("Create", "Создать"), icon: "plus", fontSize: 10, horizontalPadding: 10, verticalPadding: 5, minHeight: 26) {
                            manager.addNewProfile(name: newName, baseUrl: newBaseUrl, loginPath: newLoginPath, statsApiPath: newApiPath)
                            isAddingSite = false
                        }
                        
                        Button(loc("Cancel", "Отмена")) {
                            isAddingSite = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 16)
            }
            
            // Inline Config Editor
            if isEditingConfig {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Service URL:", "Адрес сервиса:"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("https://example.com", text: $editBaseUrl)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Login Page:", "Страница входа:"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("/login", text: $editLoginPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("Stats API URL:", "Stats API URL:"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("/api/admin/stats", text: $editApiPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VibeInteractiveHoverButton(text: loc("Apply", "Применить"), icon: "checkmark", fontSize: 10, horizontalPadding: 10, verticalPadding: 5, minHeight: 26) {
                            manager.baseUrl = editBaseUrl
                            manager.loginPath = editLoginPath
                            manager.statsApiPath = editApiPath
                            
                            // Update current profile in list
                            if let idx = manager.profiles.firstIndex(where: { $0.id == manager.currentProfileId }) {
                                manager.profiles[idx].baseUrl = editBaseUrl
                                manager.profiles[idx].loginPath = editLoginPath
                                manager.profiles[idx].statsApiPath = editApiPath
                                manager.saveProfiles()
                            }
                            
                            Task {
                                await manager.fetchStats()
                            }
                            isEditingConfig = false
                        }
                        
                        if manager.profiles.count > 1 {
                            Button(action: {
                                manager.removeProfile(id: manager.currentProfileId)
                                isEditingConfig = false
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 16)
            }
            
            // Error notice
            if let err = manager.errorMessage, !manager.isOnline {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            
            // Auth State: If NOT logged in, show direct login card
            if !manager.isLoggedIn {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(loc("Log in to tracked service (\(currentProfileName))", "Авторизация на отслеживаемом сервисе (\(currentProfileName))"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                            Text(loc("To access dashboard metrics, log in to the site as an administrator:", "Для доступа к метрикам дашборда войдите на сайт под учетной записью администратора:"))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        // URL of service input
                        HStack(spacing: 4) {
                            Text(loc("Website:", "Сайт:"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            TextField("https://example.com", text: $manager.baseUrl)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        // Button to launch login window
                        VibeInteractiveHoverButton(text: loc("Open Login Window", "Открыть окно входа"), icon: "globe", fontSize: 10, horizontalPadding: 12, verticalPadding: 5, minHeight: 26) {
                            manager.startLoginFlow()
                        }
                    }
                    
                    // Manual cookie fallback option
                    HStack(spacing: 6) {
                        Text(loc("Or cookie / token:", "Или cookie / токен:"))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        
                        SecureField("better-auth.session_token=...", text: $manager.authCookieOrToken)
                            .textFieldStyle(.plain)
                            .font(.system(size: 9, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        Button(loc("Connect", "Подключить")) {
                            Task {
                                await manager.fetchStats()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                .padding(.horizontal, 16)
            } else {
                // Logged In: Show Dynamic KPI Cards and Status Chips (Auto-parsed from any JSON!)
                VStack(spacing: 8) {
                    // Session status subline
                    HStack(spacing: 8) {
                        Text(loc("Service: \(manager.getNormalizedBaseUrl())", "Сервис: \(manager.getNormalizedBaseUrl())"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            manager.logout()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text(loc("Logout", "Выйти"))
                            }
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    
                    // Main KPI Metrics: Render dynamically parsed metrics
                    let displayMetrics = manager.metricsList.isEmpty ? defaultFallbackMetrics : manager.metricsList
                    
                    if displayMetrics.count <= 5 {
                        HStack(spacing: 8) {
                            ForEach(displayMetrics) { item in
                                KPIGlassCard(
                                    title: item.displayTitle,
                                    value: item.value,
                                    icon: item.icon,
                                    color: item.color
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(displayMetrics) { item in
                                    KPIGlassCard(
                                        title: item.displayTitle,
                                        value: item.value,
                                        icon: item.icon,
                                        color: item.color
                                    )
                                    .frame(minWidth: 95)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Status Chips Row: Render dynamically parsed statuses (sources, services, servers)
                    let displayStatuses = manager.statusChipsList
                    if !displayStatuses.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("СОСТОЯНИЕ СИСТЕМЫ И ИСТОЧНИКОВ (HEALTH MONITOR)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(displayStatuses) { item in
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(item.statusColor)
                                                .frame(width: 6, height: 6)
                                            
                                            Text(item.name.capitalized)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(.white)
                                            
                                            Text(item.statusText)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(item.statusColor)
                                            
                                            if let detail = item.detail {
                                                Text(detail)
                                                    .font(.system(size: 8, design: .monospaced))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .heroGlassCard(cornerRadius: 8)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .onAppear {
            Task {
                await manager.fetchStats()
            }
        }
    }
    
    // Default fallback metrics if waiting for first response
    private var defaultFallbackMetrics: [DynamicMetricItem] {
        [
            DynamicMetricItem(key: "totalUsers", displayTitle: "ПОЛЬЗОВАТЕЛИ", value: "\(manager.usersStats.totalUsers)", icon: "person.2.fill", color: .blue),
            DynamicMetricItem(key: "newUsers7d", displayTitle: "НОВЫЕ (7Д)", value: "+\(manager.usersStats.newUsers7d)", icon: "person.badge.plus.fill", color: .green),
            DynamicMetricItem(key: "activeUsers7d", displayTitle: "АКТИВНЫЕ (7Д)", value: "\(manager.usersStats.activeUsers7d)", icon: "bolt.fill", color: .orange),
            DynamicMetricItem(key: "analyses7d", displayTitle: "АНАЛИЗЫ (7Д)", value: "\(manager.usersStats.analyses7d)", icon: "sparkles", color: .purple),
            DynamicMetricItem(key: "marksTotal", displayTitle: "ОЦЕНКИ", value: "\(manager.usersStats.marksTotal)", icon: "star.fill", color: .yellow)
        ]
    }
}

struct KPIGlassCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color == .white ? .white : color)
                    .shadow(color: (color == .white ? Color.white : color).opacity(0.4), radius: 4)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .heroGlassCard(cornerRadius: 12)
    }
}
