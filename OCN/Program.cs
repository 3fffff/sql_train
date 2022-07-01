using System;
using System.Data;
using System.Linq;
using System.Net;
using System.Threading;
using Oracle.ManagedDataAccess.Client;


namespace OCN
{
    class Program
    {
        public static bool IsNotified;
        static void Main(string[] args)
        {
            //const string constr = "Data Source=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=omegat)(PORT=1521)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=omega))); Validate Connection = true; Connection Timeout=180;User Id=user;Password=password";
            const string str = "user id=user;password=password;data source=omegat";
            OracleConnection con = null;
            try
            {
                con = new OracleConnection();
                con.ConnectionString = str;
               // OracleCommand cmd = new OracleCommand("select * from TESTUSER.TESTTABLE", con);
                con.Open();

                OracleDependency.Port = 8000;

               /* var dep = new OracleDependency(cmd);
                cmd.Notification.IsNotifiedOnce = false;
                cmd.Notification.Timeout = 300;

                dep.OnChange += OnMyNotificaton;

                //регистрируем уведомление на сервере
                cmd.ExecuteNonQuery();*/
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
            }
            finally
            {
                if (con != null)
                {
                    con.Close();
                    con.Dispose();
                }
            }

            // проверка 10 раз в секунду
            while (IsNotified == false)
            {
                Thread.Sleep(100);
            }
            getIP();
            Console.ReadLine();
            
        }
        private static void OnMyNotificaton(object sender, OracleNotificationEventArgs eventArgs)
        {
            Console.WriteLine("Notification Received");
            DataTable changeDetails = eventArgs.Details;
            Console.WriteLine("Data has changed in {0}",
              changeDetails.Rows[0]["ResourceName"]);
            IsNotified = true;
        }
        static IPAddress getIP() {
            return Dns.GetHostEntry("948-358ZU-06").AddressList.Where(o => o.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork).First();
            
            /*  Console.WriteLine(ip);
            string name = Dns.GetHostEntry(ip).HostName.ToString();
            Console.WriteLine(name);*/
        }
    }
}
