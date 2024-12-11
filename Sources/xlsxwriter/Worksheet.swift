//
//  Worksheet.swift
//  Created by Daniel Müllenborn on 31.12.20.
//

import libxlsxwriter

/// Struct to represent an Excel worksheet.
public struct Worksheet {
    private var lxw_worksheet: UnsafeMutablePointer<lxw_worksheet>
    
    var name: String { String(cString: lxw_worksheet.pointee.name) }
    
    init(_ lxw_worksheet: UnsafeMutablePointer<lxw_worksheet>) { self.lxw_worksheet = lxw_worksheet }
    /// Insert a chart object into a worksheet.
    public func insertChart(_ chart: Chart, position pos: (row: Int, col: Int)) -> Worksheet {
        let r = UInt32(pos.row)
        let c = UInt16(pos.col)
        _ = worksheet_insert_chart(lxw_worksheet, r, c, chart.lxw_chart)
        return self
    }

    /// Insert a chart object into a worksheet, with options.
    public func insertChart(_ chart: Chart, position pos: (row: Int, col: Int), scale: (x: Double, y: Double))
        -> Worksheet {
        let r = UInt32(pos.row)
        let c = UInt16(pos.col)
        var o = lxw_chart_options(
            x_offset: 0, y_offset: 0, x_scale: scale.x, y_scale: scale.y, object_position: 2,
            description: nil, decorative: 0
        )
        worksheet_insert_chart_opt(lxw_worksheet, r, c, chart.lxw_chart, &o)
        return self
    }

    /// Write a column of data starting from (row, col).
    @discardableResult public func writeColumn(_ values: [Value], cell: Cell, format: Format? = nil)
        -> Worksheet {
        var r = cell.row
        let c = cell.column
        for value in values {
            writeValue(value, cell: .init(r, c), format: format)
            r += 1
        }
        return self
    }

    /// Write a row of data starting from (row, col).
    @discardableResult public func writeRow(_ values: [Value], cell: Cell, format: Format? = nil)
        -> Worksheet {
        let r = cell.row
        var c = cell.column
        for value in values {
            writeValue(value, cell: .init(r, c), format: format)
            c += 1
        }
        return self
    }

    /// Write a row of Double values starting from (row, col).
    @discardableResult public func writeNumbers(
        _ numbers: [Double], row: Int, col: Int = 0, format: Format? = nil
    ) -> Worksheet {
        let f = format?.lxw_format
        let r = UInt32(row)
        var c = UInt16(col)
        for number in numbers {
            worksheet_write_number(lxw_worksheet, r, c, number, f)
            c += 1
        }

        return self
    }

    /// Write a row of String values starting from (row, col).
    @discardableResult public func writeStrings(
        _ strings: [String], row: Int, col: Int = 0, format: Format? = nil
    ) -> Worksheet {
        let f = format?.lxw_format
        let r = UInt32(row)
        var c = UInt16(col)
        for string in strings {
            let _ = string.withCString { s in worksheet_write_string(lxw_worksheet, r, c, s, f) }
            c += 1
        }

        return self
    }

    /// Write data to a worksheet cell by calling the appropriate
    /// worksheet_write_*() method based on the type of data being passed.
    @discardableResult public func writeValue(_ value: Value, cell: Cell, format: Format? = nil)
        -> Worksheet {
        let r = cell.row
        let c = cell.column
        let f = format?.lxw_format
        let error: lxw_error
        switch value {
        case let .number(number): error = worksheet_write_number(lxw_worksheet, r, c, number, f)
        case let .string(string):
            error = string.withCString { s in worksheet_write_string(lxw_worksheet, r, c, s, f) }
        case let .url(url):
            error = url.absoluteString.withCString { s in worksheet_write_url(lxw_worksheet, r, c, s, f) }
        case .blank: error = worksheet_write_blank(lxw_worksheet, r, c, f)
        case let .comment(comment):
            error = comment.withCString { s in worksheet_write_comment(lxw_worksheet, r, c, s) }
        case let .boolean(boolean):
            error = worksheet_write_boolean(lxw_worksheet, r, c, Int32(boolean ? 1 : 0), f)
        case let .formula(formula):
            error = formula.withCString { s in worksheet_write_formula(lxw_worksheet, r, c, s, f) }
        case let .datetime(datetime):
            error = lxw_error(rawValue: 0)
            let num = (datetime.timeIntervalSince1970 / 86400) + 25569
            worksheet_write_number(lxw_worksheet, r, c, num, f)
        }
        if error.rawValue != 0 { fatalError(String(cString: lxw_strerror(error))) }

        return self
    }

    /// Set a worksheet tab as selected.
    @discardableResult public func select() -> Worksheet {
        worksheet_select(lxw_worksheet)
        return self
    }

    /// Hide the current worksheet.
    @discardableResult public func hide() -> Worksheet {
        worksheet_hide(lxw_worksheet)
        return self
    }

    /// Make a worksheet the active, i.e., visible worksheet.
    @discardableResult public func activate() -> Worksheet {
        worksheet_activate(lxw_worksheet)
        return self
    }

    /// Hide zero values in worksheet cells.
    @discardableResult public func hideZero() -> Worksheet {
        worksheet_hide_zero(lxw_worksheet)
        return self
    }

    /// Set the paper type for printing.
    @discardableResult public func paper(ofType type: PaperType) -> Worksheet {
        worksheet_set_paper(lxw_worksheet, type.rawValue)
        return self
    }

    /// Set the properties for one or more columns of cells.
    @discardableResult public func column(_ cols: ColumnRange, width: Double, format: Format? = nil)
        -> Worksheet {
        let first = cols.startColumn
        let last = cols.endColumn
        let f = format?.lxw_format
        _ = worksheet_set_column(lxw_worksheet, first, last, width, f)
        return self
    }

    /// Set the properties for a row of cells
    @discardableResult public func row(_ row: UInt32, height: Double, format: Format? = nil) -> Worksheet {
        let f = format?.lxw_format
        _ = worksheet_set_row(lxw_worksheet, row, height, f)
        return self
    }

    /// Set the properties for one or more columns of cells.
    @discardableResult public func hideColumns(_ col: Int, width: Double = 8.43) -> Worksheet {
        let first = UInt16(col)
        let cols: ColumnRange = "A:XFD"
        let last = cols.endColumn
        var o = lxw_row_col_options(hidden: 1, level: 0, collapsed: 0)
        _ = worksheet_set_column_opt(lxw_worksheet, first, last, width, nil, &o)
        return self
    }

    /// Set the color of the worksheet tab.
    @discardableResult public func tabColor(_ color: Color) -> Worksheet {
        worksheet_set_tab_color(lxw_worksheet, color.hex)
        return self
    }

    /// Set the default row properties.
    @discardableResult public func defaultRowHeight(_ height: Double, hideUnusedRows: Bool = true)
        -> Worksheet {
        let hide: UInt8 = hideUnusedRows ? 1 : 0
        worksheet_set_default_row(lxw_worksheet, height, hide)
        return self
    }

    /// Set the print area for a worksheet.
    @discardableResult public func printArea(forRange range: CellRange) -> Worksheet {
        let _ = worksheet_print_area(lxw_worksheet, range.startRow, range.startColumn, range.endRow, range.endColumn)
        return self
    }

    /// Set the autofilter area in the worksheet.
    @discardableResult public func autoFilter(forRange range: CellRange) -> Worksheet {
        let _ = worksheet_autofilter(lxw_worksheet, range.startRow, range.startColumn, range.endRow, range.endColumn)
        return self
    }

    /// Set the option to display or hide gridlines on the screen and the printed page.
    @discardableResult public func gridline(onScreen screen: Bool, print: Bool = false) -> Worksheet {
        worksheet_gridlines(lxw_worksheet, UInt8((print ? 2 : 0) + (screen ? 1 : 0)))
        return self
    }

    /// Set a table in the worksheet.
    @discardableResult public func table(forRange
        range: CellRange, name: String? = nil, header: [(String, Format?)] = []
    ) -> Worksheet {
        table(
            forRange: range, name: name, header: header.map { $0.0 }, format: header.map { $0.1 },
            totalRow: []
        )
    }

    /// Merge a range of cells in the worksheet.
    @discardableResult public func mergeCell(forRange range: CellRange, string: String, format: Format? = nil)
        -> Worksheet {
        worksheet_merge_range(
            lxw_worksheet, range.startRow, range.startColumn, range.endRow, range.endColumn, string, format?.lxw_format
        )
        return self
    }

    /// Set a table in the worksheet.
    @discardableResult public func table(
        forRange range: CellRange, name: String? = nil, header: [String] = [], format: [Format?] = [],
        totalRow: [TotalFunction] = []
    ) -> Worksheet {
        var options = lxw_table_options()
        if let name = name { options.name = makeCString(from: name) }
        options.style_type = UInt8(LXW_TABLE_STYLE_TYPE_MEDIUM.rawValue)
        options.style_type_number = 7
        options.total_row = totalRow.isEmpty ? UInt8(LXW_FALSE.rawValue) : UInt8(LXW_TRUE.rawValue)
        var table_columns = [lxw_table_column]()
        let buffer = UnsafeMutableBufferPointer<UnsafeMutablePointer<lxw_table_column>?>.allocate(
            capacity: header.count + 1)
        defer { buffer.deallocate() }
        if !header.isEmpty {
            table_columns = Array(repeating: lxw_table_column(), count: header.count)
            for i in header.indices {
                table_columns[i].header = makeCString(from: header[i])
                if format.endIndex > i {
                    table_columns[i].header_format = format[i]?.lxw_format
                }
                if totalRow.endIndex > i {
                    table_columns[i].total_function = totalRow[i].rawValue
                }
                withUnsafeMutablePointer(to: &table_columns[i]) {
                    buffer.baseAddress?.advanced(by: i).pointee = $0
                }
            }
            options.columns = buffer.baseAddress
        }
        _ = worksheet_add_table(
            lxw_worksheet, range.startRow, range.startColumn, range.endRow + (totalRow.isEmpty ? 0 : 1), range.endColumn,
            &options
        )
        if let _ = name { options.name.deallocate() }
        table_columns.forEach { $0.header.deallocate() }
        return self
    }
}

private func makeCString(from str: String) -> UnsafePointer<CChar> {
    str.withCString { $0 }
}
