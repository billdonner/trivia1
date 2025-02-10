import SwiftUI
import Observation

// MARK: - Data Models

struct Challenge: Codable, Identifiable {
    var id: UUID = UUID()  // Automatically assigned; not decoded from JSON.
    let topic: String
    let correct: String
    let explanation: String
    let hint: String
    let answers: [String]
    let question: String
    let difficulty: String?
    let model: String?
    
    private enum CodingKeys: String, CodingKey {
        case topic, correct, explanation, hint, answers, question, difficulty, model
    }
}

enum CellState {
    case unplayed
    case correct
    case incorrect
    case special
}

struct GameCell: Identifiable {
    var id = UUID()
    var challenge: Challenge
    var state: CellState = .unplayed
    // Grid positioning
    var row: Int
    var col: Int
}

// MARK: - ViewModel

@Observable
final class GameViewModel {
    var gridSize: Int = 4 // For example, a 4x4 board; can be set via Settings.
    var cells: [[GameCell]] = []
    var selectedCell: (row: Int, col: Int)? = nil
    var score: Int = 0
    var timeRemaining: Int = 60
    var gameFinished: Bool = false
    var showChallengeSheet: Bool = false
    var currentChallenge: Challenge? = nil
    var useSwitchQuestion: Bool = false // Flag to indicate question switching
    
    var isLoading: Bool = true  // New property: true until challenges are loaded.
    
    var timer: Timer?
    
    // Load all challenges from all JSON files in the bundle.
    func loadChallenges() {
        isLoading = true
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            print("No JSON files found in bundle.")
            isLoading = false
            return
        }
        var allChallenges: [Challenge] = []
        let decoder = JSONDecoder()
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let challengesFromFile = try decoder.decode([Challenge].self, from: data)
                allChallenges.append(contentsOf: challengesFromFile)
            } catch {
                print("Error loading \(url.lastPathComponent): \(error)")
            }
        }
        guard !allChallenges.isEmpty else {
            print("No challenges loaded! Ensure at least one JSON file contains valid challenges.")
            isLoading = false
            return
        }
        allChallenges.shuffle()
        var newCells: [[GameCell]] = []
        var index = 0
        for row in 0..<gridSize {
            var rowCells: [GameCell] = []
            for col in 0..<gridSize {
                let challenge = allChallenges[index % allChallenges.count]
                let initialState: CellState = (Bool.random() && row != 0 && col != 0 && row != gridSize-1 && col != gridSize-1) ? .incorrect : .unplayed
                rowCells.append(GameCell(challenge: challenge, state: initialState, row: row, col: col))
                index += 1
            }
            newCells.append(rowCells)
        }
        cells = newCells
        score = 0
        gameFinished = false
        selectedCell = nil
        isLoading = false
    }
    
    func startTimer() {
        timer?.invalidate()
        timeRemaining = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timeRemaining -= 1
            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                // Dismiss any open challenge sheet in your UI if needed.
                self.gameFinished = true
            }
        }
    }
    
    func selectCell(row: Int, col: Int) {
        if selectedCell == nil {
            if (row == 0 && col == 0) || (row == 0 && col == gridSize-1) ||
               (row == gridSize-1 && col == 0) || (row == gridSize-1 && col == gridSize-1) {
                selectedCell = (row, col)
                presentChallenge(for: row, col: col)
            }
        } else {
            if let last = selectedCell, isAdjacent(from: last, to: (row, col)) {
                selectedCell = (row, col)
                presentChallenge(for: row, col: col)
            }
        }
    }
    
    func isAdjacent(from: (row: Int, col: Int), to: (row: Int, col: Int)) -> Bool {
        let dr = abs(from.row - to.row)
        let dc = abs(from.col - to.col)
        return dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0)
    }
    
    func presentChallenge(for row: Int, col: Int) {
        let cell = cells[row][col]
        if cell.state == .unplayed || cell.state == .special {
            currentChallenge = cell.challenge
            showChallengeSheet = true
        }
    }
    
    func processAnswer(_ answer: String, forRow row: Int, col: Int) {
        guard let challenge = currentChallenge else { return }
        var cell = cells[row][col]
        if answer == challenge.correct {
            cell.state = .correct
            score += (challenge.difficulty == "hard" ? 2 : 1)
        } else {
            cell.state = .incorrect
        }
        cells[row][col] = cell
        showChallengeSheet = false
    }
    
    func switchQuestion(forRow row: Int, col: Int) {
        if let randomChallenge = cells.flatMap({ $0 }).randomElement()?.challenge {
            currentChallenge = randomChallenge
        }
    }
    
    // Stub for special cell behavior.
    func processSpecialCell(correctlyAnswered: Bool, forRow row: Int, col: Int) {
        // Implement special cell logic.
    }
    
    func restartGame() {
        loadChallenges()
        startTimer()
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State var viewModel = GameViewModel()
    @State private var selectedCellPosition: (row: Int, col: Int)? = nil
    
    var body: some View {
        VStack {
            headerView
            if viewModel.isLoading {
                ProgressView("Loading challenges...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else if viewModel.gameFinished {
                gameOverView
            } else {
                boardView
            }
        }
        .onAppear {
            viewModel.loadChallenges()
            viewModel.startTimer()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showChallengeSheet },
            set: { viewModel.showChallengeSheet = $0 }
        )) {
            if let pos = viewModel.selectedCell, let challenge = viewModel.currentChallenge {
                ChallengeModalView(challenge: challenge, onAnswer: { answer in
                    viewModel.processAnswer(answer, forRow: pos.row, col: pos.col)
                }, onSwitch: {
                    viewModel.switchQuestion(forRow: pos.row, col: pos.col)
                })
            }
        }
    }
    
    var headerView: some View {
        VStack {
            Text("Trivia Game")
                .font(.largeTitle)
                .padding(.bottom, 4)
            HStack {
                Text("Time Remaining: \(viewModel.timeRemaining) sec")
                    .foregroundColor(viewModel.timeRemaining <= 15 ? .red : .black)
                Spacer()
                Text("Score: \(viewModel.score)")
            }
            .font(.headline)
            .padding(.horizontal)
        }
        .padding()
    }
    
    var gameOverView: some View {
        VStack(spacing: 20) {
            Text("Game Over!")
                .font(.largeTitle)
            Text("Your score: \(viewModel.score) out of \(viewModel.cells.flatMap { $0 }.count)")
            Button("Restart Game") {
                viewModel.restartGame()
            }
            .padding()
        }
    }
    
    var boardView: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(viewModel.gridSize)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: 2), count: viewModel.gridSize), spacing: 2) {
                ForEach(0..<viewModel.gridSize, id: \.self) { row in
                    ForEach(0..<viewModel.gridSize, id: \.self) { col in
                        let cell = viewModel.cells[row][col]
                        CellView(cell: cell)
                            .frame(width: cellSize, height: cellSize)
                            .onTapGesture {
                                if cell.state == .unplayed || cell.state == .special {
                                    viewModel.selectedCell = (row, col)
                                    selectedCellPosition = (row, col)
                                    viewModel.presentChallenge(for: row, col: col)
                                }
                            }
                    }
                }
            }
            .padding()
        }
    }
}

struct CellView: View {
    let cell: GameCell
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorForState(cell.state, topic: cell.challenge.topic))
                .border(borderColorForState(cell.state), width: cell.state == .correct || cell.state == .special ? 3 : 1)
        }
    }
    
    func colorForState(_ state: CellState, topic: String) -> Color {
        switch state {
        case .unplayed:
            return topicColor(topic)
        case .correct, .special:
            return Color.green.opacity(0.5)
        case .incorrect:
            return Color.black
        }
    }
    
    func borderColorForState(_ state: CellState) -> Color {
        switch state {
        case .correct, .special:
            return .green
        case .incorrect:
            return .black
        default:
            return .gray
        }
    }
    
    func topicColor(_ topic: String) -> Color {
        let colors: [Color] = [.blue, .orange, .purple, .pink, .yellow]
        let index = abs(topic.hashValue) % colors.count
        return colors[index].opacity(0.3)
    }
}

struct ChallengeModalView: View {
    let challenge: Challenge
    var onAnswer: (String) -> Void
    var onSwitch: () -> Void
    @State private var switchEnabled: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text(challenge.question)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
            ForEach(challenge.answers, id: \.self) { answer in
                Button(action: {
                    onAnswer(answer)
                }) {
                    Text(answer)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            HStack {
                Button("Switch Question") {
                    onSwitch()
                }
                .disabled(!switchEnabled)
            }
        }
        .padding()
    }
}

@main
struct TriviaGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
