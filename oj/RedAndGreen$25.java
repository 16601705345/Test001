package oj.q1to100;

import java.util.Scanner;

public class RedAndGreen$25 {
    public static void main(String[] args) {
        // please define the JAVA input here. For example: Scanner s = new Scanner(System.in);
        Scanner scan = new Scanner(System.in);
        String s = scan.nextLine();
        // please finish the function body here.
        int count = 0;
        while (s.contains("GR")) {      //每一个"GR"序列都需要重涂一次
            s = s.replaceFirst("GR", "");
            count++;
        }
        // please define the JAVA output here. For example: System.out.println(s.nextInt());
        System.out.println(count);
    }
}
