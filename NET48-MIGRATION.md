# Nâng .NET Framework 4.8 — 27/10/2026

## Thay đổi đã thực hiện

- Sáu project ứng dụng/thư viện chính và hai project kiểm tra báo cáo nhắm v4.8. Giữ Release x64, Debug AnyCPU và phiên bản thư viện hiện có.
- Cấu hình khởi động dùng sku .NETFramework,Version=v4.8; CLR vẫn là v4.0. Prerequisite ClickOnce của ứng dụng đổi từ .NET 2.0 sang 4.8. Không thay payload, SQL, MD5 hoặc chính sách ngoại lệ HTTP đã thống nhất.
- NetTiers bổ sung enum v4_8 ở cuối (không đổi giá trị enum cũ), ánh xạ 4.8, đổi mặc định và sàn SQL lên 4.8. Các nhánh DataAnnotations/handler dành cho .NET 4+ nhận diện phiên bản mới; các thuộc tính này chỉ tác động khi sinh lại code, không tự sinh lại Entities hiện tại.
- Profile NetTiers.csp chọn v4_8, trỏ về bộ template D:\CursorAICty\NetTiers-SqlSecurity và output D:\CursorAICty\HocPhiChung2026. Giữ các lựa chọn database/bảng/view, namespace và ExecuteSql của profile gốc. KHÔNG chạy profile này trong kiểm thử vì nó đang bật ExecuteSql.
- Template cấu hình ứng dụng sinh supportedRuntime 4.8; generator CodeSmith tiếp tục dùng cơ chế compiler/host hiện có. Không đổi host template thành 4.8 một cách máy móc.

## Môi trường build

Máy hiện có runtime mới hơn 4.8 nhưng thiếu Developer Pack 4.8. Thao tác chạy installer bị kiểm duyệt tự động chặn, nên không cài hoặc thay runtime hệ thống. Đã dùng Microsoft.NETFramework.ReferenceAssemblies.net48 phiên bản 1.0.3 từ NuGet chính thức trong thư mục .framework-reference (bị Git loại trừ).

Trên máy mới, ưu tiên cài Developer Pack 4.8 theo quy trình quản trị. Nếu chưa có, chạy:

```powershell
./tools/framework/Restore-Net48ReferenceAssemblies.ps1
```

Framework48.props được import bởi các project để dùng bộ tham chiếu cục bộ khi máy chưa có targeting pack. Script compile kiểm tra sử dụng reference assemblies 4.8, thêm TargetFrameworkAttribute và cấu hình chạy 4.8; không dùng thư mục DLL runtime để giả định framework đích.

Trong repo NetTiers, dùng Tests/framework/Restore-Net48ReferenceAssemblies.ps1. Bộ reference này chỉ phục vụ biên dịch, không thay thế runtime trên máy người dùng hoặc bộ prerequisite ClickOnce. Cần nghiệm thu gói Publish/ClickOnce riêng nếu sử dụng cách triển khai đó.

## Kiểm chứng

- Trước nâng: build Debug thành công; 199 kiểm tra bảo mật ứng dụng và 120 kiểm tra API từ source NetTiers đạt.
- Sau nâng: build Debug thành công; kiểm tra metadata 6 assembly Debug và 6 assembly Release đều .NETFramework,Version=v4.8. Release EXE là AMD64.
- Sau nâng: 77 cấu hình/token/DPAPI + 60 API/session + 62 layout/transport = 199 kiểm tra đạt. NetTiers đạt 120 kiểm tra API trên hai namespace.
- Báo cáo Excel: build và chạy offline, PASS 103 kiểm tra. Harness được bổ sung file ExcelExportFileName.cs thật đang được mã báo cáo sử dụng; không thay nghiệp vụ để làm test vượt qua. LiveReports.Probe build thành công, không chạy kết nối database thật.
- CodeSmith 7.1 thực sự biên dịch template chính và các template đăng ký; kiểm tra mặc định v4_8, ExecuteSql=False của template. Sinh 12 tổ hợp Entities/Data/SqlClient/Services x v4/v4_5/v4_8: đều v4.8 và render lần hai giống hệt. Cấu hình runtime sinh ra là 4.8 và lặp lại không đổi.
- Engine test chỉ render project/config với collections rỗng và provider có connection string rỗng. Không dùng schema sản xuất, không query SQL hoặc thực thi SQL. Source bảo mật được materialize và compile ở 4.8 bởi Test-ApiHardening.ps1; chưa sinh/build toàn bộ mã nghiệp vụ theo schema thật.
- So sánh các loại cảnh báo với log build trước nâng (baseline Debug và log Release x64 hiện có): chưa thấy loại cảnh báo mới. Cảnh báo cũ về generated code, XML docs, assembly conflicts và manifest/CommonLib vẫn còn; EXE không tham chiếu assembly CommonLib.

Lệnh kiểm tra:

```powershell
./scripts/security/Test-Net48Build.ps1 -Configuration Debug
./scripts/security/Test-Net48Build.ps1 -Configuration Release
./scripts/security/Test-DpapiMigration.ps1
./scripts/security/Test-ApiSurface.ps1
./scripts/security/Test-SecurityHardening.ps1
# Trong repo NetTiers:
./Tests/Test-ApiHardening.ps1
./Tests/Test-Framework48.ps1
```

## Git và bàn giao

.gitignore chỉ mở lại đúng bốn file csproj của Accounts.* bị loại trừ trước đây, đồng thời tiếp tục bỏ qua generated source/binary ở các thư mục đó. Các thay đổi nâng framework, props, script restore/test, profile và báo cáo đều hiện trong trạng thái Git để review; chưa stage/commit/push.

Repo vốn không lưu toàn bộ generated source và DLL phụ thuộc. Vì vậy một clone sạch vẫn cần bộ source/generated assets và thư viện gốc theo quy trình hiện có; thay đổi này không khẳng định đã làm toàn repo tự tái tạo được chỉ từ Git. Không đưa thêm hàng nghìn generated file hoặc cấu hình bí mật vào Git để xử lý giới hạn đó.

## Nghiệm thu trước phát hành và hoàn tác

1. Máy người dùng phải có runtime 4.8+; thử trước trên nhóm nhỏ. Dùng cùng EXE, DLL và cấu hình của một lần build.
2. Kiểm tra thực tế đăng nhập, kết nối SQL, báo cáo/in và nhập/xuất Excel với dữ liệu thử. Chưa chạy các nghiệp vụ này trên môi trường thật.
3. Kiểm tra font, cắt chữ, nút và bố cục trên các màn hình chính ở Windows 100%, 125%, 150%. Các kiểm tra GridView offline đã đạt nhưng không thay cho nghiệm thu DPI toàn ứng dụng.
4. Kiểm tra HTTPS/chứng chỉ và gửi thử email/SMS/hóa đơn tại môi trường thử. Không tự thay chính sách TLS/ngoại lệ HTTP của đợt bảo mật trước.
5. Khi cần kiểm tra sinh toàn bộ code theo schema: sao chép profile ra thư mục thử, đổi ExecuteSql=False, tắt mở VS/report, chuyển output riêng; so sánh các lớp custom/security trước khi cân nhắc đưa vào project thật. Không chạy trực tiếp profile sản xuất để kiểm chứng nâng framework.
6. Sao lưu trọn bộ chương trình/cấu hình/profile trước phát hành. Nếu lỗi, khôi phục bộ ứng dụng trước nâng; không gỡ runtime mới để cố cài runtime 4.x cũ. Không có thay đổi schema database trong lần nâng này.

## Kết quả cuối cùng

- Pipeline Release x64 + obfuscation: PASS (exit 0).
- EXE sau obfuscation: TargetFrameworkAttribute = .NETFramework,Version=v4.8, kiến trúc AMD64.
- Thư mục bản bảo vệ: .security-work/release-obfuscated-20261027-100259. Hai module đã obfuscate phải dùng cùng các thư viện/cấu hình trong HocPhi/bin/Release.
- Tổng kiểm tra hiện có sau nâng: 422 (199 ứng dụng + 120 API NetTiers + 103 báo cáo). Ngoài ra đã đạt compile master CodeSmith, cấu hình runtime sinh ra, 12 kịch bản project sinh lặp và metadata của 12 assembly Debug/Release.
- Profile học phí đã kiểm tra đủ 105 thuộc tính so với bản sao trước nâng: chỉ DotNetVersion và OutputDirectory đổi; đường dẫn template đổi riêng ở thuộc tính của propertySet. Engine test kiểm tra hash để bảo đảm profile sản xuất không bị thay đổi khi chạy thử.
- File NET48-CHANGES.json liệt kê các file thuộc lần nâng này ở cả hai repo; không bao gồm các sửa đổi nghiệp vụ đã có trước đó.

## Cập nhật Release đa kiến trúc — 27/10/2026

Theo yêu cầu mới, Release và Release-Obfuscation.bat mặc định AnyCPU với Prefer32Bit=false, thay cho cấu hình x64 cố định ở các mục lịch sử phía trên. Windows 64-bit chạy tiến trình x64; Windows 32-bit chạy tiến trình x86. Không có cơ chế tự hạ xuống x86 nếu DLL/Office 32-bit không tương thích trên Windows 64-bit.

Pipeline sử dụng Rebuild để tránh giữ lại DLL x64/x86 từ lần build trước. Kiểm tra metadata của cả 6 assembly và 2 module sau obfuscation: AnyCPU phải là I386 + ILOnly, không có Required32Bit/Preferred32Bit. Các mode x64/x86 vẫn có thể chọn rõ bằng tham số PowerShell nhưng không còn là mặc định của file bat.

Native SQL Server Types vẫn đóng gói cả thư mục x86/x64 và chọn theo IntPtr.Size. Office/Access/COM phải tương thích kiến trúc tiến trình. Kiểm tra metadata không thay thế nghiệm thu trên Windows 32-bit và kiểm thử các tính năng COM thực tế.

Kết quả kiểm chứng bản AnyCPU: Rebuild Release và obfuscation thành công. Cả 6 assembly và 2 module bảo vệ đạt ILOnly, không có cờ bắt buộc/ưu tiên 32-bit. Đã kiểm tra 93 module .NET trong đồ thị dependency cục bộ, không thấy module ép kiến trúc. Cả 6 assembly nạp được dưới tiến trình x64 và x86; msvcr120.dll và SqlServerSpatial140.dll cũng nạp thành công ở cả hai kiến trúc. Chương trình mẫu AnyCPU tự chạy x64 trên máy Windows 64-bit hiện tại. Các phép thử không gọi entry point của ứng dụng hoặc truy cập database; chưa thay cho nghiệm thu nghiệp vụ trên Windows 32-bit/COM thực tế.
