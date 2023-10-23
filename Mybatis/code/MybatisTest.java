package com.xiaohe.mybatis;

import cn.hutool.json.JSONUtil;
import com.xiaohe.mybatis.dao.StudentDao;
import com.xiaohe.mybatis.entity.Student;
import org.apache.ibatis.io.Resources;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;

/**
 * @Author smallhe
 * @Date 2022-07-01 10:03
 * @Description:
 */

public class MybatisTest {


    public static void main(String[] args) {
        SqlSessionFactory factory = null;
        String config = "config/mybatis.xml";
        try {
            InputStream inputStream = Resources.getResourceAsStream(config);
            factory = new SqlSessionFactoryBuilder().build(inputStream);
        } catch (IOException e) {
            e.printStackTrace();
        }
        if (factory != null) {
            SqlSession session = factory.openSession();
            StudentDao mapper = session.getMapper(StudentDao.class);
            List<Student> students = mapper.selectAll();
//            Student students = mapper.getStudentById("1");
            System.out.println(JSONUtil.toJsonStr(students));
            session.close();
        }
    }
}
