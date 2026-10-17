# NetTiers SQL memory protection

## Chọn template trong CodeSmith

Bộ đang chỉnh: `D:\CursorAI\HocPhiChung2025\.security-work\NetTiers`. Trong CodeSmith mở `NetTiers.cst` tại thư mục này và compile/reload template để bỏ cache template cũ. Nếu dùng NetTiers.csp, chọn lại template mới trong UI và lưu một profile riêng; profile gốc trong source còn trỏ thư mục PC2, chưa được sửa. Không dùng profile trỏ bộ template cũ.

Chọn SQL Server, EnterpriseLibrary `v3_1`, VisualStudioVersion `v2013` và output thử riêng, ví dụ `D:\CursorAI\HocPhiChung2025\.security-work\nettiers-codesmith-trial`. `ExecuteSql=False`; không chạy script SQL hoặc generate trực tiếp vào source đang dùng. Không đặt password thực trong profile bàn giao.

Bộ SQL bảo mật hiện chỉ hỗ trợ EnterpriseLibrary 3.1 đã kiểm thử. NetTiers.cst từ chối SQL provider với phiên bản khác trước luồng sinh file. CompilerVersion=v3.5 của generator không bị thay; code output cần Roslyn/C# 6 trở lên và SDK .NET Framework 4.5.2 hoặc cao hơn. Target framework của Data/SqlClient/entities output được nâng tối thiểu 4.5.2, giữ phiên bản cao hơn nếu đã chọn. Cần build bằng MSBuild/SDK mới phù hợp, không dùng compiler C# 3.5 để compile output.

## Những phần đã tích hợp

- Table provider base, view provider base và SqlNetTiersProvider sinh SecureSqlDatabase; constructor/config/setter chuyển input thành tham chiếu phiên. Getter chuỗi công khai giữ tương thích bằng ExportLegacy và vẫn có thể tạo plaintext; đường execute nội bộ dùng field opaque.
- TransactionManager giữ lease đến sau connection/transaction, rollback khi stop trước commit và dispose đúng thứ tự. Nhánh ngoài SQL giữ template cũ.
- DataRepository thay provider trùng tên và bảo vệ tham chiếu trong ConnectionProvider. Utility giữ nguyên câu SQL/tên DB log hiện có, thêm lease/disposal/redaction và không ghi nguyên SQL text tự do. Không sửa template stored procedure/schema.
- Luồng generate tự ghi lại 5 file trong Security, thêm node project và Compile Include/System.Security. Namespace lấy từ DALNameSpace; không hardcode Accounts.Data. Source assets nằm trong SecuritySource/*.cs.txt, dùng marker __DAL_NAMESPACE__.
- AppConnection, form, Program và ReleaseProtection tiếp tục tích hợp bằng gói HocPhi-SqlSecurity-Porting riêng; generator này không tự sửa các file desktop đó.

Không chuyển token sql-session sang SqlConnection/SqlConnectionStringBuilder trực tiếp. Các caller/helper bên ngoài provider vẫn phải được chuyển sang API lease như hướng dẫn porting. Nếu file cấu hình có raw SQL connection string, ConfigurationManager/caller cũ vẫn có thể giữ bản sao plaintext; template provider không thay thế việc bảo vệ cấu hình trong AppConnection.

## Kiểm tra bằng CodeSmith trên máy có engine

1. Compile template mới, chọn ít nhất một table, một view và custom stored procedure đang dùng; generate với ExecuteSql=False vào output thử.
2. Kiểm tra 5 file Security, namespace, Compile Include, target framework và references; build output bằng compiler mới.
3. Generate lần hai cùng profile vào output thử. Chạy lại build và kiểm tra không mất Security hoặc thay adapter về SqlDatabase.
4. Copy script Convert-NetTiers.py vào scripts/security của solution thử và chạy --check. Mẫu namespace khác vẫn cần kiểm tra trực tiếp constructor/config/getter/raw connection; --check không phải chứng minh an toàn toàn bộ.
5. Chạy fixture và kiểm thử SQL/Windows auth, reader/dataset, transaction commit/rollback, provider reload, custom procedure, log nhạy cảm và tác vụ đồng thời trên DB thử. Không cấp credential thực qua command line.

## Backup và cài gói ở máy khác

Backup nguyên bộ trước sửa nằm ngoài thư mục template: `.security-work/NetTiers-before-security.zip`. Patch chỉ phần sửa: `.security-work/NetTiers-security.patch`.

Gói ZIP bàn giao là overlay: 8 template đã sửa, 5 assets mới và tài liệu. Giải nén đè vào **bản sao nguyên bộ NetTiers cùng phiên bản**; giữ các template còn lại, TemplateLib, UserLib và References từ bản gốc. Không có DLL dependency, CodeSmith engine, profile kết nối, khóa riêng hoặc dump trong ZIP. Không áp dụng overlay sang version NetTiers khác mà chưa đối chiếu patch. Không cập nhật trực tiếp bộ template cài chung của CodeSmith.

## Kết quả hiện tại và giới hạn

Đã audit tĩnh các template SQL, kiểm tra source asset và dựng riêng source Security/Transaction với hai namespace Accounts.Data và PortingTrial.Data. Cả hai compile và đạt 20 assertion mỗi namespace; dựng source hai lần giống nhau. Các file gốc ngoài 8 template sửa giữ nguyên byte, nhánh TransactionManager ngoài SQL giữ nguyên output cũ.

Chưa tìm thấy CodeSmith engine trên máy hiện tại. **Chưa chạy generate schema table/view/custom procedure bằng CodeSmith, chưa build toàn solution do CodeSmith sinh, chưa xác nhận nhánh project bằng engine thật.** Dựng literal source để test không thay thế engine generation. Các bước đó còn phải thực hiện trước sử dụng production. SecureString/DPAPI/obfuscation không cam kết chống mọi dump.

## Mặc định framework đã chỉnh

Template mới mặc định DotNetVersion=v4_5, EntLibVersion=v3_1 và ExecuteSql=False. Profile cũ chọn v4 được nâng lên v4_5 trong luồng SQL; csproj đầu ra tối thiểu v4.5.2. Profile lưu sẵn có thể ghi đè giá trị mặc định, nên vẫn kiểm tra EntLibVersion và ExecuteSql sau khi mở. Không tự tắt ExecuteSql nếu người dùng bật rõ trong profile. Lỗi trùng custom method GetByBillId/GetByBillIdHoanPhi chưa được sửa bởi thay đổi framework này.

Da sua nhanh IncludeComponents (Accounts.Services): project Services sinh ra cung toi thieu v4.5.2 de tham chieu Data/Entities v4.5.2.
