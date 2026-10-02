/// Ranks for a batch of new tasks, each after the last open task of its column, so imports land in order at the
/// bottom instead of on top of what was planned.
struct ColumnEnd {
    let board: [TaskItem]
    let week: WeekRange
    private var next: [Bucket: Double] = [:]

    init(board: [TaskItem], week: WeekRange) {
        self.board = board
        self.week = week
    }

    mutating func rank(for column: Bucket) -> Double {
        let rank =
            next[column] ?? (board.filter { $0.column(in: week) == column && !$0.isDone }.map(\.rank).max() ?? 0) + 1
        next[column] = rank + 1
        return rank
    }
}
